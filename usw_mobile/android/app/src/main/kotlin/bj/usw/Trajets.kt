package bj.usw

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.net.Uri
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

/**
 * « Y aller » (lib/outils/trajets.dart) : les applications de trajet et de course installees
 * sur ce telephone (nom et icone, tels qu Android les montre), puis l ouverture de l une
 * d elles vers la destination. Android ne laisse voir que les paquets declares dans les
 * <queries> du manifeste.
 */
class Trajets(private val activite: Activity) : MethodChannel.MethodCallHandler {
    override fun onMethodCall(appel: MethodCall, resultat: MethodChannel.Result) {
        when (appel.method) {
            "installees" -> resultat.success(installees(appel.argument<List<String>>("paquets").orEmpty()))
            "ouvrir" -> resultat.success(ouvrir(appel.argument<String>("paquet"), appel.argument<String>("lien")))
            "autre" -> resultat.success(autre(appel.argument<String>("lien") ?: ""))
            else -> resultat.notImplemented()
        }
    }

    private fun installees(paquets: List<String>): List<Map<String, Any>> {
        val pm = activite.packageManager
        return paquets.mapNotNull { paquet ->
            if (pm.getLaunchIntentForPackage(paquet) == null) return@mapNotNull null
            runCatching {
                val info = pm.getApplicationInfo(paquet, 0)
                mapOf("paquet" to paquet, "nom" to pm.getApplicationLabel(info).toString(), "icone" to png(pm, paquet))
            }.getOrNull()
        }
    }

    // L icone de l application, en PNG de 96 px : assez net pour la feuille, leger a passer.
    private fun png(pm: PackageManager, paquet: String): ByteArray {
        val dessin = pm.getApplicationIcon(paquet)
        val image = Bitmap.createBitmap(96, 96, Bitmap.Config.ARGB_8888)
        dessin.setBounds(0, 0, 96, 96)
        dessin.draw(Canvas(image))
        return ByteArrayOutputStream().use { sortie ->
            image.compress(Bitmap.CompressFormat.PNG, 100, sortie)
            image.recycle()
            sortie.toByteArray()
        }
    }

    // Le lien de destination dans l application ; si elle ne le comprend pas, elle s ouvre simplement.
    private fun ouvrir(paquet: String?, lien: String?): Boolean {
        paquet ?: return false
        if (lien != null) {
            try {
                activite.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(lien)).setPackage(paquet))
                return true
            } catch (_: ActivityNotFoundException) {
            } catch (_: SecurityException) {
            }
        }
        val lancer = activite.packageManager.getLaunchIntentForPackage(paquet) ?: return false
        return runCatching { activite.startActivity(lancer) }.isSuccess
    }

    // Toute autre application qui sait ouvrir un lieu (geo:) : le choix d Android.
    private fun autre(lien: String): Boolean = runCatching {
        activite.startActivity(Intent.createChooser(Intent(Intent.ACTION_VIEW, Uri.parse(lien)), "Y aller avec"))
    }.isSuccess
}
