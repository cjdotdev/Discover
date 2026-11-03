package bj.usw

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.ExifInterface
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.effect.Presentation
import androidx.media3.transformer.Composition
import androidx.media3.transformer.DefaultEncoderFactory
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.Effects
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.Transformer
import androidx.media3.transformer.VideoEncoderSettings
import java.io.File
import java.io.RandomAccessFile
import kotlin.math.min
import kotlin.math.roundToInt

/**
 * Le fichier qui part au serveur, allege sur le telephone avant l envoi (comme TikTok) : bien
 * plus petit, donc plus vite envoye et moins de donnees, sans perte visible.
 *  - une photo : un JPEG de 4 096 px au plus (assez pour la 4K), qualite 90, avec les informations
 *    de la prise (EXIF, XMP) que le serveur relit ;
 *  - une video : la puce du telephone la reencode en 1080p, H.264 a 7 Mbit/s (au-dessus de ce que
 *    le serveur sert ensuite), son AAC.
 * Une image qui avoue venir d une IA part telle quelle : le serveur la refuse comme avant. Un
 * fichier deja leger, ou un echec, garde l original.
 */
class Optimiseur(private val contexte: Context) {
    private val principal = Handler(Looper.getMainLooper())

    private fun sortie(extension: String) = File(File(contexte.cacheDir, "envois").apply { mkdirs() }, "optimise-${System.nanoTime()}.$extension")

    // ------------------------------------------------------------ les photos

    // Ce que le serveur cherche (DetecteurIa) pour reconnaitre une image d IA.
    private val marquesIa = listOf(
        "trainedalgorithmicmedia", "algorithmicmedia", "midjourney", "dall-e", "stable diffusion", "stablediffusion", "firefly",
        "imagen", "leonardo.ai", "nightcafe", "dreamstudio", "comfyui", "automatic1111", "novelai", "ideogram", "flux.1",
    )

    private fun porteUneMarqueIa(source: String): Boolean {
        val f = File(source)
        val n = f.length()
        RandomAccessFile(f, "r").use { r ->
            val debut = ByteArray(min(n, 512L * 1024).toInt())
            r.readFully(debut)
            var fin = ByteArray(0)
            if (n > 512L * 1024) {
                val t = min(128L * 1024, n)
                r.seek(n - t)
                fin = ByteArray(t.toInt())
                r.readFully(fin)
            }
            val texte = (String(debut, Charsets.ISO_8859_1) + String(fin, Charsets.ISO_8859_1)).lowercase()
            return marquesIa.any { texte.contains(it) }
        }
    }

    // Les informations de la prise qui suivent la photo (le serveur relit le telephone, la date,
    // la position) ; l orientation aussi : les pixels ne sont pas tournes.
    private val tagsGardes = listOf(
        ExifInterface.TAG_MAKE, ExifInterface.TAG_MODEL, ExifInterface.TAG_SOFTWARE, ExifInterface.TAG_ORIENTATION,
        ExifInterface.TAG_DATETIME, ExifInterface.TAG_DATETIME_ORIGINAL, ExifInterface.TAG_DATETIME_DIGITIZED,
        "OffsetTime", "OffsetTimeOriginal", "OffsetTimeDigitized", "SubSecTimeOriginal",
        ExifInterface.TAG_GPS_LATITUDE, ExifInterface.TAG_GPS_LATITUDE_REF, ExifInterface.TAG_GPS_LONGITUDE, ExifInterface.TAG_GPS_LONGITUDE_REF,
        ExifInterface.TAG_GPS_ALTITUDE, ExifInterface.TAG_GPS_ALTITUDE_REF, ExifInterface.TAG_GPS_TIMESTAMP, ExifInterface.TAG_GPS_DATESTAMP,
        ExifInterface.TAG_FOCAL_LENGTH, ExifInterface.TAG_F_NUMBER, ExifInterface.TAG_EXPOSURE_TIME, "ISOSpeedRatings",
        ExifInterface.TAG_IMAGE_DESCRIPTION, ExifInterface.TAG_ARTIST, "Xmp",
    )

    fun photo(source: String): String {
        if (porteUneMarqueIa(source)) return source
        val bornes = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(source, bornes)
        if (bornes.outWidth <= 0 || bornes.outHeight <= 0) return source
        // Decodee a 20 Mpx au plus : un capteur de 108 ou 200 Mpx ne remplit pas la memoire.
        var echantillon = 1
        while (bornes.outWidth.toLong() / echantillon * (bornes.outHeight.toLong() / echantillon) > 20_000_000L) echantillon *= 2
        val image = BitmapFactory.decodeFile(source, BitmapFactory.Options().apply { inSampleSize = echantillon }) ?: return source
        val cote = 4096f
        val echelle = min(1f, cote / maxOf(image.width, image.height))
        val finale = if (echelle < 1f) Bitmap.createScaledBitmap(image, (image.width * echelle).roundToInt(), (image.height * echelle).roundToInt(), true) else image
        val f = sortie("jpg")
        f.outputStream().use { finale.compress(Bitmap.CompressFormat.JPEG, 90, it) }
        if (finale !== image) finale.recycle()
        image.recycle()
        runCatching {
            val de = ExifInterface(source)
            val vers = ExifInterface(f.path)
            for (tag in tagsGardes) runCatching { de.getAttribute(tag)?.let { vers.setAttribute(tag, it) } }
            vers.saveAttributes()
        }
        // Pas plus leger (une photo deja petite) : l original part.
        if (f.length() <= 0 || f.length() >= File(source).length()) {
            f.delete()
            return source
        }
        return f.path
    }

    // ------------------------------------------------------------ les videos

    /** La video allegee ; `fin` recoit son chemin (l original si elle est deja legere ou en cas d echec). */
    fun video(source: String, fin: (String) -> Unit) {
        val (largeur, hauteur, debit) = runCatching {
            val m = MediaMetadataRetriever()
            try {
                m.setDataSource(source)
                val l = m.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)?.toInt() ?: 0
                val h = m.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)?.toInt() ?: 0
                val r = m.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)?.toInt() ?: 0
                val d = m.extractMetadata(MediaMetadataRetriever.METADATA_KEY_BITRATE)?.toLong() ?: 0L
                // La taille telle qu on la voit (une video debout est souvent enregistree couchee).
                if (r == 90 || r == 270) Triple(h, l, d) else Triple(l, h, d)
            } finally {
                m.release()
            }
        }.getOrElse { return fin(source) }
        val court = min(largeur, hauteur)
        if (court <= 0) return fin(source)
        // Deja legere : 1080p ou moins, 8,5 Mbit/s ou moins. Elle part telle quelle.
        if (court <= 1088 && debit in 1..8_500_000) return fin(source)
        // Petite (moins de 20 Mo, un reel de quelques secondes) : la reencoder prend plus de temps
        // qu elle n en fait gagner a l envoi, et le serveur la reencode de toute facon.
        if (File(source).length() < 20L * 1024 * 1024) return fin(source)
        val debut = SystemClock.elapsedRealtime()
        val f = sortie("mp4")
        val effets = if (court > 1080) listOf(Presentation.createForHeight(((hauteur * 1080f / court).roundToInt() / 2) * 2)) else emptyList()
        principal.post {
            runCatching {
                val transformer = Transformer.Builder(contexte)
                    .setVideoMimeType(MimeTypes.VIDEO_H264)
                    .setAudioMimeType(MimeTypes.AUDIO_AAC)
                    .setEncoderFactory(
                        DefaultEncoderFactory.Builder(contexte)
                            .setRequestedVideoEncoderSettings(VideoEncoderSettings.Builder().setBitrate(7_000_000).build())
                            .build(),
                    )
                    .addListener(object : Transformer.Listener {
                        override fun onCompleted(composition: Composition, resultat: ExportResult) {
                            Log.i("Discover", "Video allegee en ${SystemClock.elapsedRealtime() - debut} ms : ${File(source).length() / 1024} -> ${f.length() / 1024} Ko")
                            if (f.length() in 1 until File(source).length()) fin(f.path) else {
                                f.delete()
                                fin(source)
                            }
                        }

                        override fun onError(composition: Composition, resultat: ExportResult, erreur: ExportException) {
                            f.delete()
                            fin(source)
                        }
                    })
                    .build()
                val element = EditedMediaItem.Builder(MediaItem.fromUri(Uri.fromFile(File(source))))
                    .setEffects(Effects(emptyList(), effets))
                    .build()
                transformer.start(element, f.path)
            }.onFailure {
                f.delete()
                fin(source)
            }
        }
    }
}
