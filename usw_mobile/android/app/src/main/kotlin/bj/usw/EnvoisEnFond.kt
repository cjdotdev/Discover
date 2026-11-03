package bj.usw

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.PowerManager

/**
 * Les envois continuent quand on quitte Discover (comme Instagram ou TikTok) : un service au
 * premier plan garde l application en vie le temps des envois, avec une notification qui montre
 * l avancee. Il s arrete des que tout est parti. Desactivable dans les reglages
 * (lib/donnees/envois.dart le demarre, le met a jour et l arrete).
 */
class EnvoisEnFond : Service() {
    companion object {
        private const val CANAL = "envois"
        private const val NUMERO = 7201

        fun montrer(contexte: Context, titre: String, texte: String, avance: Int) {
            val i = Intent(contexte, EnvoisEnFond::class.java)
                .putExtra("titre", titre).putExtra("texte", texte).putExtra("avance", avance)
            runCatching {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) contexte.startForegroundService(i) else contexte.startService(i)
            }
        }

        fun arreter(contexte: Context) {
            runCatching { contexte.stopService(Intent(contexte, EnvoisEnFond::class.java)) }
        }
    }

    private var eveil: PowerManager.WakeLock? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val titre = intent?.getStringExtra("titre") ?: "Discover"
        val texte = intent?.getStringExtra("texte") ?: ""
        val avance = intent?.getIntExtra("avance", -1) ?: -1
        val n = notification(titre, texte, avance)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NUMERO, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
        } else {
            startForeground(NUMERO, n)
        }
        // Le processeur reste eveille le temps des envois (30 min au plus, renouvele a chaque point).
        if (eveil == null) {
            eveil = (getSystemService(Context.POWER_SERVICE) as PowerManager)
                .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "discover:envois")
        }
        runCatching { eveil?.acquire(30 * 60 * 1000L) }
        // Tue par Android : les envois reprendront a la prochaine ouverture, pas d ici.
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        runCatching { if (eveil?.isHeld == true) eveil?.release() }
        super.onDestroy()
    }

    private fun notification(titre: String, texte: String, avance: Int): Notification {
        val gestion = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && gestion.getNotificationChannel(CANAL) == null) {
            // Discret : sans son ni vibration, il dit seulement ou en sont les envois.
            gestion.createNotificationChannel(NotificationChannel(CANAL, "Envois", NotificationManager.IMPORTANCE_LOW))
        }
        val ouvrir = PendingIntent.getActivity(
            this, 0,
            packageManager.getLaunchIntentForPackage(packageName)?.addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        @Suppress("DEPRECATION")
        val b = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) Notification.Builder(this, CANAL) else Notification.Builder(this)
        b.setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(titre)
            .setContentText(texte)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setContentIntent(ouvrir)
        if (avance in 0..100) b.setProgress(100, avance, false) else b.setProgress(0, 0, true)
        return b.build()
    }
}
