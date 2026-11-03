package bj.usw

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Les telechargements, cote Android (lib/donnees/telechargements.dart) : une notification
 * dont la barre avance pendant le telechargement, puis « Photo enregistrée » ou l echec.
 * La premiere apparait en haut de l ecran (« Téléchargement commencé »), comme WhatsApp.
 * Toucher la notification ouvre Mes envois et téléchargements dans Discover (deja ouvert ou
 * non). Sans l autorisation des notifications, rien ne s affiche ici : la progression reste
 * visible dans Discover.
 */
class Telechargements(private val contexte: Context) : MethodChannel.MethodCallHandler {
    private val notifications = contexte.getSystemService(NotificationManager::class.java)

    init {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            // Haute : elle apparait en haut de l ecran (une fois, sans son), puis se met a jour sur
            // place. L importance d un canal ne change plus apres sa creation : l ancien canal,
            // discret (seulement dans le volet), est remplace.
            notifications.deleteNotificationChannel("telechargements")
            val canal = NotificationChannel(CANAL, "Téléchargements", NotificationManager.IMPORTANCE_HIGH).apply {
                description = "La progression des photos et vidéos enregistrées dans la galerie"
                setSound(null, null)
                enableVibration(false)
            }
            notifications.createNotificationChannel(canal)
        }
    }

    override fun onMethodCall(appel: MethodCall, resultat: MethodChannel.Result) {
        val id = appel.argument<Int>("id") ?: 0
        val titre = appel.argument<String>("titre") ?: ""
        val texte = appel.argument<String>("texte") ?: ""
        when (appel.method) {
            // Discover ouvert par une notification de telechargement : la page a montrer.
            "ouvertureEnAttente" -> {
                resultat.success(enAttente)
                enAttente = null
                return
            }
            "avance" -> afficher(id, titre, texte, appel.argument<Int>("pourcent") ?: 0, enCours = true)
            "fin" -> afficher(id, titre, texte, 100, enCours = false)
            else -> return resultat.notImplemented()
        }
        resultat.success(null)
    }

    private fun afficher(id: Int, titre: String, texte: String, pourcent: Int, enCours: Boolean) {
        val ouvrir = PendingIntent.getActivity(
            contexte,
            BASE + id,
            Intent(contexte, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
                .putExtra(OUVRIR, PAGE),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val construction = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) Notification.Builder(contexte, CANAL) else @Suppress("DEPRECATION") Notification.Builder(contexte)
        construction
            .setSmallIcon(if (enCours) android.R.drawable.stat_sys_download else R.drawable.ic_notification)
            .setContentTitle(titre)
            .setContentText(texte)
            .setContentIntent(ouvrir)
            .setOnlyAlertOnce(true)
            .setCategory(Notification.CATEGORY_PROGRESS)
            .setOngoing(enCours)
            .setAutoCancel(!enCours)
        // Avant Android 8, la priorite haute fait apparaitre la notification en haut de l ecran.
        @Suppress("DEPRECATION")
        construction.setPriority(Notification.PRIORITY_HIGH)
        if (enCours) construction.setProgress(100, pourcent, pourcent <= 0)
        runCatching { notifications.notify(BASE + id, construction.build()) }
    }

    companion object {
        private const val CANAL = "telechargements-visibles"
        private const val BASE = 4000
        const val OUVRIR = "discover_ouvrir"
        private const val PAGE = "/creer/envois"

        /** Discover ouvert (ou rouvert) depuis une notification : la page, en attendant Dart. */
        var enAttente: String? = null

        /** La page demandee par une notification touchee, si c en est une. */
        fun pageDe(intention: Intent?): String? = intention?.getStringExtra(OUVRIR)?.takeIf { it == PAGE }
    }
}
