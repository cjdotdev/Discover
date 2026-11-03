package bj.usw

import android.Manifest
import android.app.Activity
import android.app.ActivityManager
import android.content.ContentResolver
import android.content.ContentUris
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.Geocoder
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.database.ContentObserver
import android.media.ExifInterface
import android.opengl.EGL14
import android.opengl.EGLConfig
import android.opengl.GLES20
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import android.media.MediaMuxer
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.provider.MediaStore
import android.provider.Settings
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.TextView
import com.google.android.gms.common.api.ResolvableApiException
import com.google.android.gms.location.CurrentLocationRequest
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.LocationSettingsRequest
import com.google.android.gms.location.Priority
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.nio.ByteBuffer
import java.security.MessageDigest
import java.util.Locale
import kotlin.concurrent.thread

/**
 * L appareil photo du telephone, le vrai, avec tous ses modes (lib/outils/appareil.dart).
 *
 * Une application qui demande « prends une photo et rends-la moi » recoit
 * l ecran reduit de l appareil photo (photo seule, zoom 1x et 2x). USW ouvre
 * plutot l appareil photo complet, comme depuis l ecran d accueil, puis, au
 * retour, cherche dans la galerie ce qui vient d etre pris : une ou plusieurs
 * photos, une video. Rien ne tourne dans USW pendant ce temps.
 *
 * Le retour tout seul : autorise a s afficher par-dessus les autres applis, Discover pose une
 * pastille « ‹ Discover » sur l appareil photo et guette la galerie ; des que la prise est
 * enregistree (finie d ecrire), il revient devant avec elle. Android interdit a une app en
 * arriere-plan de revenir d elle-meme, sauf avec cette autorisation et une fenetre visible.
 * Les prises se reconnaissent a leur numero dans la galerie, plus grand que le dernier avant
 * l ouverture (pas a leur date) ; une video encore en train de s ecrire est attendue.
 *
 * Aussi : couper une video a 60 s (sans la reencoder), en tirer une image, et
 * proposer d allumer la localisation (la fenetre d Android, en un toucher).
 */
class Appareil(private val activite: Activity) : MethodChannel.MethodCallHandler {
    companion object {
        const val CODE_PERMISSIONS = 7101
        const val CODE_POSITION = 7102
        const val CODE_AUDIO = 7103
    }

    private val principal = Handler(Looper.getMainLooper())
    private val optimiseur by lazy { Optimiseur(activite) }

    // La prise en cours : l appareil photo est ouvert, on attend le retour.
    private var attente: MethodChannel.Result? = null
    private var depuisSecondes = 0L
    private var videoDemandee = false
    private var cache = false

    // Les derniers numeros de la galerie avant l ouverture : une prise a un numero plus grand. Notes
    // aussi sur le telephone, si Android ferme Discover pendant la prise.
    private var dernierImage = 0L
    private var dernierVideo = 0L
    private val notes by lazy { activite.getSharedPreferences("discover_prise", Context.MODE_PRIVATE) }

    // Le retour tout seul : la galerie guettee, la pastille sur l appareil photo.
    private var observateur: ContentObserver? = null
    private var pastille: View? = null
    private var verification: Runnable? = null

    // Une demande de permissions, puis l ouverture.
    private var apresPermissions: (() -> Unit)? = null
    private var attentePosition: MethodChannel.Result? = null

    // Un fichier audio choisi dans le telephone (un son pour un reel).
    private var attenteAudio: MethodChannel.Result? = null

    override fun onMethodCall(appel: MethodCall, resultat: MethodChannel.Result) {
        when (appel.method) {
            "ouvrir" -> ouvrir(appel.argument<Boolean>("video") ?: false, resultat)
            "depuis" -> {
                val ms = (appel.argument<Number>("depuis") ?: 0).toLong()
                val image = notes.getLong("image", 0)
                val video = notes.getLong("video", 0)
                thread { val l = attendrePrises(ms / 1000, image, video); principal.post { resultat.success(l) } }
            }
            "retourAuto" -> resultat.success(Build.VERSION.SDK_INT < 23 || Settings.canDrawOverlays(activite))
            "demanderRetourAuto" -> {
                runCatching { activite.startActivity(Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:${activite.packageName}"))) }
                resultat.success(null)
            }
            "couper" -> {
                val chemin = appel.argument<String>("chemin")!!
                val debutMs = (appel.argument<Number>("debutMs") ?: 0).toLong()
                val finMs = (appel.argument<Number>("finMs") ?: 60000).toLong()
                val son = appel.argument<Boolean>("son") ?: true
                thread {
                    val sortie = runCatching { couper(chemin, debutMs * 1000, finMs * 1000, son) }.getOrNull()
                    principal.post { resultat.success(sortie) }
                }
            }
            "vignette" -> {
                val chemin = appel.argument<String>("chemin")!!
                thread {
                    val sortie = runCatching { vignette(chemin) }.getOrNull()
                    principal.post { resultat.success(sortie) }
                }
            }
            "apercu" -> {
                val chemin = appel.argument<String>("chemin")!!
                val cote = (appel.argument<Number>("cote") ?: 2160).toInt()
                thread {
                    val sortie = runCatching { apercu(chemin, cote) }.getOrNull()
                    principal.post { resultat.success(sortie) }
                }
            }
            // Les envois continuent hors de l application (EnvoisEnFond.kt).
            "envoisEnFond" -> {
                EnvoisEnFond.montrer(
                    activite,
                    appel.argument<String>("titre") ?: "Discover",
                    appel.argument<String>("texte") ?: "",
                    (appel.argument<Number>("avance") ?: -1).toInt(),
                )
                resultat.success(null)
            }
            "envoisFinis" -> {
                EnvoisEnFond.arreter(activite)
                resultat.success(null)
            }
            // Le fichier qui part au serveur, allege ici avant l envoi (Optimiseur.kt).
            "optimiser" -> {
                val chemin = appel.argument<String>("chemin")!!
                if (appel.argument<Boolean>("video") == true) {
                    optimiseur.video(chemin) { sortie -> principal.post { resultat.success(sortie) } }
                } else {
                    thread {
                        val sortie = runCatching { optimiseur.photo(chemin) }.getOrDefault(chemin)
                        principal.post { resultat.success(sortie) }
                    }
                }
            }
            "empreinte" -> {
                val chemin = appel.argument<String>("chemin")!!
                thread {
                    val sortie = runCatching { empreinte(chemin) }.getOrNull()
                    principal.post { resultat.success(sortie) }
                }
            }
            // Le son d une video (la piste audio seule, recopiee telle quelle : aussitot).
            "extraireSon" -> {
                val source = appel.argument<String>("chemin") ?: return resultat.success(null)
                thread {
                    val chemin = runCatching { extraireSon(source) }.getOrNull()
                    principal.post { resultat.success(chemin) }
                }
            }
            "choisirAudio" -> choisirAudio(resultat)
            "activerPosition" -> activerPosition(resultat)
            "position" -> positionFraiche(resultat)
            "adresse" -> {
                val lat = (appel.argument<Number>("lat") ?: 0).toDouble()
                val lon = (appel.argument<Number>("lon") ?: 0).toDouble()
                thread {
                    val a = runCatching { adresse(lat, lon) }.getOrNull()
                    principal.post { resultat.success(a) }
                }
            }
            // USW peut-il lire ce que l appareil photo vient d ajouter a la galerie ?
            "acces" -> resultat.success(accorde(permissionsMedias().first()))
            "capacites" -> thread {
                val c = runCatching { capacites() }.getOrNull()
                principal.post { resultat.success(c) }
            }
            else -> resultat.notImplemented()
        }
    }

    // ------------------------------------------------------------ ce que le telephone peut afficher

    // Sa memoire, s il se dit « petit » (Android Go), et la plus grande image que sa carte
    // graphique accepte : au-dela, une photo ne s affiche pas.
    private fun capacites(): Map<String, Any> {
        val gestion = activite.getSystemService(Activity.ACTIVITY_SERVICE) as ActivityManager
        val memoire = ActivityManager.MemoryInfo().also { gestion.getMemoryInfo(it) }
        return mapOf(
            "memoireMo" to (memoire.totalMem / (1024 * 1024)).toInt(),
            "faible" to gestion.isLowRamDevice,
            "textureMax" to textureMax(),
        )
    }

    // Un contexte OpenGL de 1 px, le temps de lire GL_MAX_TEXTURE_SIZE, puis rendu.
    private fun textureMax(): Int = runCatching {
        val affichage = EGL14.eglGetDisplay(EGL14.EGL_DEFAULT_DISPLAY)
        val version = IntArray(2)
        EGL14.eglInitialize(affichage, version, 0, version, 1)
        val attributs = intArrayOf(EGL14.EGL_RENDERABLE_TYPE, EGL14.EGL_OPENGL_ES2_BIT, EGL14.EGL_SURFACE_TYPE, EGL14.EGL_PBUFFER_BIT, EGL14.EGL_NONE)
        val configs = arrayOfNulls<EGLConfig>(1)
        val nombre = IntArray(1)
        EGL14.eglChooseConfig(affichage, attributs, 0, configs, 0, 1, nombre, 0)
        val contexte = EGL14.eglCreateContext(affichage, configs[0], EGL14.EGL_NO_CONTEXT, intArrayOf(EGL14.EGL_CONTEXT_CLIENT_VERSION, 2, EGL14.EGL_NONE), 0)
        val surface = EGL14.eglCreatePbufferSurface(affichage, configs[0], intArrayOf(EGL14.EGL_WIDTH, 1, EGL14.EGL_HEIGHT, 1, EGL14.EGL_NONE), 0)
        EGL14.eglMakeCurrent(affichage, surface, surface, contexte)
        val max = IntArray(1)
        GLES20.glGetIntegerv(GLES20.GL_MAX_TEXTURE_SIZE, max, 0)
        EGL14.eglMakeCurrent(affichage, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_CONTEXT)
        EGL14.eglDestroySurface(affichage, surface)
        EGL14.eglDestroyContext(affichage, contexte)
        max[0]
    }.getOrDefault(0).let { if (it > 0) it else 4096 }

    // ------------------------------------------------------------ ouvrir

    private fun permissionsMedias(): Array<String> = when {
        Build.VERSION.SDK_INT >= 33 -> arrayOf(
            Manifest.permission.READ_MEDIA_IMAGES,
            Manifest.permission.READ_MEDIA_VIDEO,
            Manifest.permission.ACCESS_MEDIA_LOCATION,
        )
        Build.VERSION.SDK_INT >= 29 -> arrayOf(Manifest.permission.READ_EXTERNAL_STORAGE, Manifest.permission.ACCESS_MEDIA_LOCATION)
        else -> arrayOf(Manifest.permission.READ_EXTERNAL_STORAGE)
    }

    private fun accorde(p: String) = activite.checkSelfPermission(p) == PackageManager.PERMISSION_GRANTED

    private fun ouvrir(video: Boolean, resultat: MethodChannel.Result) {
        attente?.success(emptyList<Any>())
        val manque = permissionsMedias().filterNot(::accorde)
        if (manque.isEmpty()) return lancer(video, resultat)
        apresPermissions = { lancer(video, resultat) }
        activite.requestPermissions(manque.toTypedArray(), CODE_PERMISSIONS)
    }

    fun permissionsRecues(code: Int): Boolean {
        if (code != CODE_PERMISSIONS) return false
        val suite = apresPermissions
        apresPermissions = null
        suite?.invoke()
        return true
    }

    // L application d appareil photo du telephone (celle qui repond a « prendre
    // une photo »), ouverte en grand plutot qu en ecran reduit.
    private fun lancer(video: Boolean, resultat: MethodChannel.Result) {
        // Sans acces a la galerie, USW ne retrouverait pas la prise : Dart ouvre
        // alors l appareil photo en ecran simple, qui rend le fichier directement.
        if (!accorde(permissionsMedias().first())) return resultat.error("sans_acces", "Galerie refusee", null)
        val pm = activite.packageManager
        val paquet = pm.resolveActivity(Intent(MediaStore.ACTION_IMAGE_CAPTURE), 0)?.activityInfo?.packageName
        val action = if (video) MediaStore.INTENT_ACTION_VIDEO_CAMERA else MediaStore.INTENT_ACTION_STILL_IMAGE_CAMERA
        val intention = Intent(action).apply { if (paquet != null && paquet != "android") setPackage(paquet) }
        depuisSecondes = System.currentTimeMillis() / 1000 - 1
        videoDemandee = video
        cache = false
        dernierImage = dernierNumero(MediaStore.Images.Media.EXTERNAL_CONTENT_URI)
        dernierVideo = dernierNumero(MediaStore.Video.Media.EXTERNAL_CONTENT_URI)
        notes.edit().putLong("image", dernierImage).putLong("video", dernierVideo).apply()
        try {
            attente = resultat
            activite.startActivity(intention)
        } catch (_: Exception) {
            try {
                activite.startActivity(Intent(action))
            } catch (e: Exception) {
                attente = null
                resultat.error("appareil", "Pas d'appareil photo", null)
                return
            }
        }
        guetter()
    }

    // Le plus grand numero de la galerie (les prises en cours d ecriture comprises).
    private fun dernierNumero(source: Uri): Long = runCatching {
        val colonnes = arrayOf(MediaStore.MediaColumns._ID)
        val curseur = if (Build.VERSION.SDK_INT >= 30) {
            activite.contentResolver.query(
                source, colonnes,
                Bundle().apply {
                    putString(ContentResolver.QUERY_ARG_SQL_SORT_ORDER, "${MediaStore.MediaColumns._ID} DESC")
                    putInt(ContentResolver.QUERY_ARG_LIMIT, 1)
                    putInt(MediaStore.QUERY_ARG_MATCH_PENDING, MediaStore.MATCH_INCLUDE)
                },
                null,
            )
        } else {
            activite.contentResolver.query(source, colonnes, null, null, "${MediaStore.MediaColumns._ID} DESC")
        }
        curseur?.use { if (it.moveToFirst()) it.getLong(0) else 0L } ?: 0L
    }.getOrDefault(0L)

    // ------------------------------------------------------------ le retour tout seul

    private fun guetter() {
        if (Build.VERSION.SDK_INT < 23 || !Settings.canDrawOverlays(activite)) return
        montrerPastille()
        val o = object : ContentObserver(principal) {
            override fun onChange(selfChange: Boolean) = verifierBientot()
        }
        observateur = o
        for (u in listOf(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, MediaStore.Video.Media.EXTERNAL_CONTENT_URI)) {
            runCatching { activite.contentResolver.registerContentObserver(u, true, o) }
        }
    }

    // La galerie a bouge : une prise finie d ecrire ? (un demi-seconde de calme d abord)
    private fun verifierBientot() {
        verification?.let { principal.removeCallbacks(it) }
        val depuis = depuisSecondes
        val image = dernierImage
        val video = dernierVideo
        val r = Runnable {
            thread {
                val prete = nouvelles(depuis, image, video).any { it.prete }
                if (prete) principal.post { revenir() }
            }
        }
        verification = r
        principal.postDelayed(r, 500)
    }

    // Discover devant, pendant que la pastille est encore visible (Android l exige) ; elle part
    // au retour (reprend).
    private fun revenir() {
        if (attente == null) return arreterGuet()
        runCatching {
            activite.startActivity(
                Intent(activite, activite.javaClass).addFlags(
                    Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_NEW_TASK,
                ),
            )
        }
    }

    private fun montrerPastille() {
        if (pastille != null) return
        val d = activite.resources.displayMetrics.density
        val vue = TextView(activite).apply {
            text = "‹  Discover"
            setTextColor(Color.WHITE)
            textSize = 14f
            typeface = Typeface.DEFAULT_BOLD
            setPadding((12 * d).toInt(), (9 * d).toInt(), (16 * d).toInt(), (9 * d).toInt())
            background = GradientDrawable().apply {
                setColor(0xD91C1D22.toInt())
                cornerRadii = floatArrayOf(0f, 0f, 22 * d, 22 * d, 22 * d, 22 * d, 0f, 0f)
            }
            contentDescription = "Discover"
            setOnClickListener { revenir() }
        }
        val reglages = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.START or Gravity.TOP
            y = (activite.resources.displayMetrics.heightPixels * 0.42).toInt()
        }
        runCatching {
            (activite.applicationContext.getSystemService(Context.WINDOW_SERVICE) as WindowManager).addView(vue, reglages)
            pastille = vue
        }
    }

    fun arreterGuet() {
        verification?.let { principal.removeCallbacks(it) }
        verification = null
        observateur?.let { o -> runCatching { activite.contentResolver.unregisterContentObserver(o) } }
        observateur = null
        pastille?.let { v -> runCatching { (activite.applicationContext.getSystemService(Context.WINDOW_SERVICE) as WindowManager).removeView(v) } }
        pastille = null
    }

    /** L appareil photo couvre USW : au prochain retour, on cherche la prise. */
    fun arrete() {
        if (attente != null) cache = true
    }

    /** USW revient devant : la photo est peut-etre encore en train de s enregistrer. */
    fun reprend() {
        arreterGuet()
        val r = attente ?: return
        if (!cache) return
        attente = null
        cache = false
        val depuis = depuisSecondes
        val image = dernierImage
        val video = dernierVideo
        thread {
            val liste = attendrePrises(depuis, image, video)
            principal.post { r.success(liste) }
        }
    }

    // L appareil photo finit parfois d ecrire apres notre retour (un telephone lent, une batterie
    // faible) : 6 s si rien n apparait, jusqu a 40 s si une prise est en train de s ecrire.
    private fun attendrePrises(depuis: Long, image: Long, video: Long): List<Map<String, Any>> {
        val debut = SystemClock.elapsedRealtime()
        while (true) {
            val trouvees = nouvelles(depuis, image, video)
            if (trouvees.any { it.prete }) return copier(trouvees.filter { it.prete })
            val enCours = trouvees.isNotEmpty()
            if (SystemClock.elapsedRealtime() - debut > (if (enCours) 40_000 else 6_000)) return emptyList()
            Thread.sleep(400)
        }
    }

    private class Trouvee(val uri: Uri, val video: Boolean, val date: Long, val nom: String, val prete: Boolean)

    // Ce qui est arrive dans la galerie depuis l ouverture : un numero plus grand que le dernier
    // d avant (sinon, sans numero note, la date d ajout). Une prise encore en train de s ecrire
    // (en attente, ou vide) n est pas « prete ».
    private fun nouvelles(depuis: Long, apresImage: Long, apresVideo: Long): List<Trouvee> {
        val liste = mutableListOf<Trouvee>()
        val sources = listOf(
            Triple(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, false, apresImage),
            Triple(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, true, apresVideo),
        )
        val colonnes = mutableListOf(MediaStore.MediaColumns._ID, MediaStore.MediaColumns.DATE_ADDED, MediaStore.MediaColumns.DISPLAY_NAME, MediaStore.MediaColumns.SIZE)
            .apply { if (Build.VERSION.SDK_INT >= 29) add(MediaStore.MediaColumns.IS_PENDING) }
            .toTypedArray()
        for ((source, video, apres) in sources) {
            runCatching {
                val (selection, arguments) = if (apres > 0) {
                    "${MediaStore.MediaColumns._ID} > ?" to arrayOf(apres.toString())
                } else {
                    "${MediaStore.MediaColumns.DATE_ADDED} >= ?" to arrayOf(depuis.toString())
                }
                val curseur = if (Build.VERSION.SDK_INT >= 30) {
                    activite.contentResolver.query(
                        source, colonnes,
                        Bundle().apply {
                            putString(ContentResolver.QUERY_ARG_SQL_SELECTION, selection)
                            putStringArray(ContentResolver.QUERY_ARG_SQL_SELECTION_ARGS, arguments)
                            putString(ContentResolver.QUERY_ARG_SQL_SORT_ORDER, "${MediaStore.MediaColumns._ID} DESC")
                            putInt(MediaStore.QUERY_ARG_MATCH_PENDING, MediaStore.MATCH_INCLUDE)
                        },
                        null,
                    )
                } else {
                    activite.contentResolver.query(source, colonnes, selection, arguments, "${MediaStore.MediaColumns._ID} DESC")
                }
                curseur?.use { c ->
                    while (c.moveToNext() && liste.size < 20) {
                        val enAttente = Build.VERSION.SDK_INT >= 29 && c.getInt(4) == 1
                        liste.add(Trouvee(ContentUris.withAppendedId(source, c.getLong(0)), video, c.getLong(1), c.getString(2) ?: "prise", !enAttente && c.getLong(3) > 0))
                    }
                }
            }
        }
        return liste.sortedByDescending { it.date }
    }

    // Les prises, du plus recent au plus ancien, copiees dans le cache d USW avec leurs
    // informations d origine.
    private fun copier(trouvees: List<Trouvee>): List<Map<String, Any>> {
        val resultat = mutableListOf<Map<String, Any>>()
        val dossier = File(activite.cacheDir, "prises").apply { mkdirs() }
        for (t in trouvees.take(10)) {
            val uri = t.uri
            val video = t.video
            val info = t.date to t.nom
            val nom = info.second.replace(Regex("[^A-Za-z0-9._-]"), "_")
            val cible = File(dossier, "${System.nanoTime()}-$nom")
            // L original : avec la position inscrite dans la photo (sinon Android l efface).
            val origine = if (Build.VERSION.SDK_INT >= 29 && accorde(Manifest.permission.ACCESS_MEDIA_LOCATION)) {
                runCatching { MediaStore.setRequireOriginal(uri) }.getOrDefault(uri)
            } else {
                uri
            }
            val copie = runCatching {
                activite.contentResolver.openInputStream(origine)!!.use { e -> cible.outputStream().use { s -> e.copyTo(s) } }
            }.recoverCatching {
                activite.contentResolver.openInputStream(uri)!!.use { e -> cible.outputStream().use { s -> e.copyTo(s) } }
            }
            if (copie.isSuccess && cible.length() > 0) {
                resultat.add(mapOf("chemin" to cible.path, "video" to video, "date" to info.first * 1000))
            }
        }
        return resultat
    }

    // ------------------------------------------------------------ couper, vignette

    // La video de debutUs a finUs, sans reencoder : on recopie les images et le son tels
    // quels (le debut part de l image cle juste avant). Sans `son`, la piste audio est
    // laissee de cote. Rapide, et rien ne chauffe.
    private fun couper(source: String, debutUs: Long, finUs: Long, son: Boolean): String {
        val extracteur = MediaExtractor().apply { setDataSource(source) }
        val sortie = File(File(activite.cacheDir, "prises").apply { mkdirs() }, "reel-${System.currentTimeMillis()}.mp4")
        val muxeur = MediaMuxer(sortie.path, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        val pistes = HashMap<Int, Int>()
        var taille = 4 shl 20
        for (i in 0 until extracteur.trackCount) {
            val format = extracteur.getTrackFormat(i)
            val mime = format.getString(MediaFormat.KEY_MIME) ?: continue
            if (!mime.startsWith("video/") && !(son && mime.startsWith("audio/"))) continue
            extracteur.selectTrack(i)
            pistes[i] = muxeur.addTrack(format)
            if (format.containsKey(MediaFormat.KEY_MAX_INPUT_SIZE)) taille = maxOf(taille, format.getInteger(MediaFormat.KEY_MAX_INPUT_SIZE))
        }
        val lecteur = MediaMetadataRetriever()
        runCatching {
            lecteur.setDataSource(source)
            lecteur.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)?.toIntOrNull()?.let { muxeur.setOrientationHint(it) }
        }
        lecteur.release()
        muxeur.start()
        // Le debut : l image cle juste avant, pour que la video demarre nette ; les temps
        // repartent de zero.
        if (debutUs > 0) extracteur.seekTo(debutUs, MediaExtractor.SEEK_TO_PREVIOUS_SYNC)
        val base = if (debutUs > 0) maxOf(0L, extracteur.sampleTime) else 0L
        val tampon = ByteBuffer.allocate(taille)
        val info = MediaCodec.BufferInfo()
        while (true) {
            val piste = extracteur.sampleTrackIndex
            if (piste < 0) break
            val temps = extracteur.sampleTime
            if (temps > finUs) {
                extracteur.unselectTrack(piste)
                continue
            }
            if (temps < base) {
                extracteur.advance()
                continue
            }
            info.offset = 0
            info.size = extracteur.readSampleData(tampon, 0)
            if (info.size < 0) break
            info.presentationTimeUs = temps - base
            info.flags = if ((extracteur.sampleFlags and MediaExtractor.SAMPLE_FLAG_SYNC) != 0) MediaCodec.BUFFER_FLAG_KEY_FRAME else 0
            muxeur.writeSampleData(pistes[piste]!!, tampon, info)
            extracteur.advance()
        }
        muxeur.stop()
        muxeur.release()
        extracteur.release()
        return sortie.path
    }

    /** La piste audio d une video, seule, dans un .m4a ; nul sans piste audio. */
    private fun extraireSon(source: String): String? {
        val extracteur = MediaExtractor().apply { setDataSource(source) }
        try {
            val piste = (0 until extracteur.trackCount).firstOrNull {
                extracteur.getTrackFormat(it).getString(MediaFormat.KEY_MIME)?.startsWith("audio/") == true
            } ?: return null
            val format = extracteur.getTrackFormat(piste)
            val sortie = File(File(activite.cacheDir, "sons").apply { mkdirs() }, "son-${System.currentTimeMillis()}.m4a")
            val muxeur = MediaMuxer(sortie.path, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
            try {
                val index = muxeur.addTrack(format)
                extracteur.selectTrack(piste)
                muxeur.start()
                val taille = if (format.containsKey(MediaFormat.KEY_MAX_INPUT_SIZE)) maxOf(1 shl 16, format.getInteger(MediaFormat.KEY_MAX_INPUT_SIZE)) else 1 shl 20
                val tampon = ByteBuffer.allocate(taille)
                val info = MediaCodec.BufferInfo()
                while (true) {
                    info.offset = 0
                    info.size = extracteur.readSampleData(tampon, 0)
                    if (info.size < 0) break
                    info.presentationTimeUs = extracteur.sampleTime
                    info.flags = if ((extracteur.sampleFlags and MediaExtractor.SAMPLE_FLAG_SYNC) != 0) MediaCodec.BUFFER_FLAG_KEY_FRAME else 0
                    muxeur.writeSampleData(index, tampon, info)
                    extracteur.advance()
                }
                muxeur.stop()
            } catch (e: Exception) {
                sortie.delete()
                return null
            } finally {
                runCatching { muxeur.release() }
            }
            return if (sortie.length() > 0) sortie.path else null
        } finally {
            extracteur.release()
        }
    }

    /** Le selecteur de fichiers d Android, pour un fichier audio ; le fichier est copie dans l application. */
    private fun choisirAudio(resultat: MethodChannel.Result) {
        attenteAudio?.success(null)
        attenteAudio = resultat
        val intention = Intent(Intent.ACTION_GET_CONTENT).setType("audio/*").addCategory(Intent.CATEGORY_OPENABLE)
        runCatching { activite.startActivityForResult(Intent.createChooser(intention, null), CODE_AUDIO) }.onFailure {
            attenteAudio = null
            resultat.success(null)
        }
    }

    // La premiere image d une video, 720 px de large : la couverture du reel.
    private fun vignette(source: String): String {
        val lecteur = MediaMetadataRetriever()
        try {
            lecteur.setDataSource(source)
            val image = lecteur.getFrameAtTime(0, MediaMetadataRetriever.OPTION_CLOSEST_SYNC) ?: error("pas d'image")
            val largeur = minOf(720, image.width)
            val reduite = Bitmap.createScaledBitmap(image, largeur, image.height * largeur / image.width, true)
            val sortie = File(File(activite.cacheDir, "prises").apply { mkdirs() }, "vignette-${System.nanoTime()}.jpg")
            sortie.outputStream().use { reduite.compress(Bitmap.CompressFormat.JPEG, 85, it) }
            if (reduite !== image) reduite.recycle()
            image.recycle()
            return sortie.path
        } finally {
            lecteur.release()
        }
    }

    // ------------------------------------------------------------ l envoi

    // L apercu qui part d abord : la photo redressee, 2 160 px au plus, en WebP
    // (quelques centaines de Ko au lieu de plusieurs Mo). Sans metadonnees.
    private fun apercu(source: String, cote: Int): String {
        val bornes = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(source, bornes)
        var echantillon = 1
        while (maxOf(bornes.outWidth, bornes.outHeight) / (echantillon * 2) >= cote) echantillon *= 2
        val image = BitmapFactory.decodeFile(source, BitmapFactory.Options().apply { inSampleSize = echantillon }) ?: error("image illisible")
        val angle = when (runCatching { ExifInterface(source).getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL) }.getOrDefault(ExifInterface.ORIENTATION_NORMAL)) {
            ExifInterface.ORIENTATION_ROTATE_90 -> 90f
            ExifInterface.ORIENTATION_ROTATE_180 -> 180f
            ExifInterface.ORIENTATION_ROTATE_270 -> 270f
            else -> 0f
        }
        val echelle = minOf(1f, cote.toFloat() / maxOf(image.width, image.height))
        val m = Matrix().apply { postScale(echelle, echelle); postRotate(angle) }
        val finale = if (echelle < 1f || angle != 0f) Bitmap.createBitmap(image, 0, 0, image.width, image.height, m, true) else image
        val sortie = File(File(activite.cacheDir, "envois").apply { mkdirs() }, "apercu-${System.nanoTime()}.webp")
        @Suppress("DEPRECATION")
        val format = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) Bitmap.CompressFormat.WEBP_LOSSY else Bitmap.CompressFormat.WEBP
        sortie.outputStream().use { finale.compress(format, 82, it) }
        if (finale !== image) finale.recycle()
        image.recycle()
        return sortie.path
    }

    // L empreinte SHA-256 du fichier : le serveur verifie que rien ne s est abime en route.
    private fun empreinte(source: String): String {
        val md = MessageDigest.getInstance("SHA-256")
        File(source).inputStream().use { entree ->
            val tampon = ByteArray(1 shl 16)
            while (true) {
                val n = entree.read(tampon)
                if (n <= 0) break
                md.update(tampon, 0, n)
            }
        }
        return md.digest().joinToString("") { "%02x".format(it) }
    }

    // ------------------------------------------------------------ la localisation

    // Le nom du lieu d une position (quartier, ville, pays), par le service
    // d Android lui-meme : sans cle ni fournisseur de cartes. Il faut Internet.
    private fun adresse(lat: Double, lon: Double): Map<String, String>? {
        if (!Geocoder.isPresent()) return null
        @Suppress("DEPRECATION")
        val a = Geocoder(activite, Locale.FRENCH).getFromLocation(lat, lon, 1)?.firstOrNull() ?: return null
        return mapOf(
            "quartier" to (a.subLocality ?: ""),
            "ville" to (a.locality ?: a.subAdminArea ?: ""),
            "region" to (a.adminArea ?: ""),
            "pays" to (a.countryName ?: ""),
            "code" to (a.countryCode ?: ""),
        )
    }

    // La fenetre du systeme « Activer la localisation », sans quitter USW : si la
    // localisation est coupee, ou allumee sans la precision (GPS, Wi-Fi) qu il faut.
    // Tout est deja bon : aucune fenetre, oui tout de suite.
    private fun activerPosition(resultat: MethodChannel.Result) {
        val demande = LocationSettingsRequest.Builder()
            .addLocationRequest(LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, 10_000).build())
            .setAlwaysShow(true)
            .build()
        LocationServices.getSettingsClient(activite).checkLocationSettings(demande)
            .addOnSuccessListener { resultat.success(true) }
            .addOnFailureListener { e ->
                if (e is ResolvableApiException) {
                    try {
                        attentePosition = resultat
                        e.startResolutionForResult(activite, CODE_POSITION)
                    } catch (_: Exception) {
                        attentePosition = null
                        resultat.success(false)
                    }
                } else {
                    resultat.success(false)
                }
            }
    }

    // Une position fraiche : le telephone la cherche vraiment (GPS, Wi-Fi), au lieu
    // d attendre qu une autre application en ait demande une. Une position de
    // moins d une minute sert telle quelle.
    @Suppress("MissingPermission")
    private fun positionFraiche(resultat: MethodChannel.Result) {
        if (!accorde(Manifest.permission.ACCESS_FINE_LOCATION) && !accorde(Manifest.permission.ACCESS_COARSE_LOCATION)) {
            resultat.success(null)
            return
        }
        var rendu = false
        fun rendre(valeur: Map<String, Double>?) {
            if (rendu) return
            rendu = true
            resultat.success(valeur)
        }
        val demande = CurrentLocationRequest.Builder()
            .setPriority(Priority.PRIORITY_HIGH_ACCURACY)
            .setMaxUpdateAgeMillis(60_000)
            .setDurationMillis(15_000)
            .build()
        runCatching {
            LocationServices.getFusedLocationProviderClient(activite).getCurrentLocation(demande, null)
                .addOnSuccessListener { l -> rendre(l?.let { mapOf("lat" to it.latitude, "lon" to it.longitude) }) }
                .addOnFailureListener { rendre(null) }
        }.onFailure { rendre(null) }
    }

    fun resultatActivite(code: Int, retour: Int, donnees: Intent? = null): Boolean {
        if (code == CODE_AUDIO) {
            val attente = attenteAudio ?: return true
            attenteAudio = null
            val uri = donnees?.data
            if (retour != Activity.RESULT_OK || uri == null) {
                attente.success(null)
                return true
            }
            thread {
                val chemin = runCatching {
                    val sortie = File(File(activite.cacheDir, "sons").apply { mkdirs() }, "fichier-${System.currentTimeMillis()}")
                    activite.contentResolver.openInputStream(uri)!!.use { entree -> sortie.outputStream().use { entree.copyTo(it) } }
                    sortie.path
                }.getOrNull()
                principal.post { attente.success(chemin) }
            }
            return true
        }
        if (code != CODE_POSITION) return false
        attentePosition?.success(retour == Activity.RESULT_OK)
        attentePosition = null
        return true
    }
}
