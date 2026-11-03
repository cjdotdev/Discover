package bj.usw

import android.app.ActivityManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * La sobriete, cote Android (lib/outils/sobriete.dart) : la temperature du
 * telephone, l economiseur de batterie et sa puissance. Quand il chauffe ou
 * economise, l ecran revient a sa frequence normale (60 Hz) et l application
 * s allege ; quand il refroidit, elle redevient fluide (90, 120 Hz).
 * Une FragmentActivity : l empreinte de « Gerer Discover » (local_auth) en a besoin.
 */
class MainActivity : FlutterFragmentActivity() {
    private var canal: MethodChannel? = null
    private var canalTelechargements: MethodChannel? = null
    private val appareil = Appareil(this)
    private var reseau: Reseau? = null
    private var chaleur = -1
    private var ecouteChaleur: PowerManager.OnThermalStatusChangedListener? = null

    private val economie = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) = signaler()
    }

    private val puissance by lazy { getSystemService(Context.POWER_SERVICE) as PowerManager }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        canal = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "bj.usw/sobriete").apply {
            setMethodCallHandler { appel, resultat ->
                if (appel.method == "etat") resultat.success(etat()) else resultat.notImplemented()
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "bj.usw/appareil").setMethodCallHandler(appareil)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "bj.usw/trajets").setMethodCallHandler(Trajets(this))
        canalTelechargements = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "bj.usw/telechargements").apply {
            setMethodCallHandler(Telechargements(this@MainActivity))
        }
        val canalReseau = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "bj.usw/reseau")
        reseau = Reseau(this, canalReseau).also {
            canalReseau.setMethodCallHandler(it)
            it.demarrer()
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        // Ouverte depuis une notification de telechargement : Dart la demandera au demarrage.
        if (savedInstanceState == null) Telechargements.pageDe(intent)?.let { Telechargements.enAttente = it }
        super.onCreate(savedInstanceState)
        appliquerFrequence()
        creerCanalNotifications()
    }

    // Le canal des notifications de Discover (reactions, commentaires, abonnes, equipe) :
    // son nom s affiche dans les reglages Android de l application.
    private fun creerCanalNotifications() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val canal = NotificationChannel("activite", "Activité", NotificationManager.IMPORTANCE_HIGH).apply {
            description = "Réactions, commentaires, abonnés et messages de l’équipe"
        }
        getSystemService(NotificationManager::class.java).createNotificationChannel(canal)
    }

    override fun onResume() {
        super.onResume()
        // Le telephone a pu chauffer ou refroidir pendant l absence.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            chaleur = puissance.currentThermalStatus
            val ecoute = PowerManager.OnThermalStatusChangedListener { statut ->
                chaleur = statut
                signaler()
            }
            puissance.addThermalStatusListener(mainExecutor, ecoute)
            ecouteChaleur = ecoute
        }
        registerReceiver(economie, IntentFilter(PowerManager.ACTION_POWER_SAVE_MODE_CHANGED))
        signaler()
        // De retour de l appareil photo : on cherche ce qui vient d etre pris.
        appareil.reprend()
    }

    // Deja ouverte : la notification touchee ouvre la page aussitot.
    override fun onNewIntent(intention: Intent) {
        super.onNewIntent(intention)
        setIntent(intention)
        val page = Telechargements.pageDe(intention) ?: return
        canalTelechargements?.invokeMethod("ouvrir", page) ?: run { Telechargements.enAttente = page }
    }

    override fun onStop() {
        appareil.arrete()
        super.onStop()
    }

    override fun onRequestPermissionsResult(code: Int, permissions: Array<out String>, resultats: IntArray) {
        super.onRequestPermissionsResult(code, permissions, resultats)
        appareil.permissionsRecues(code)
    }

    @Deprecated("Toujours appele par Android pour les fenetres de Google Play services.")
    override fun onActivityResult(code: Int, retour: Int, donnees: Intent?) {
        super.onActivityResult(code, retour, donnees)
        appareil.resultatActivite(code, retour, donnees)
    }

    override fun onDestroy() {
        reseau?.arreter()
        appareil.arreterGuet()
        super.onDestroy()
    }

    override fun onPause() {
        // En arriere-plan, on n ecoute plus rien : rien ne tourne pour rien.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) ecouteChaleur?.let { puissance.removeThermalStatusListener(it) }
        ecouteChaleur = null
        runCatching { unregisterReceiver(economie) }
        super.onPause()
    }

    private fun petitTelephone(): Boolean {
        val activite = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val memoire = ActivityManager.MemoryInfo().also { activite.getMemoryInfo(it) }
        return activite.isLowRamDevice || memoire.totalMem < 3L * 1024 * 1024 * 1024
    }

    // La lentille du verre (ImageFilter.shader) ne se dessine bien qu avec Vulkan :
    // sur OpenGL ES (pas de Vulkan 1.1, puces PowerVR), ce qui passe derriere le
    // verre sortait noir. Ces telephones gardent le verre, sans lentille.
    private val lentillePossible by lazy {
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q &&
            packageManager.hasSystemFeature(PackageManager.FEATURE_VULKAN_HARDWARE_VERSION, 0x401000) &&
            !proprieteSysteme("ro.hardware.egl").contains("powervr", ignoreCase = true)
    }

    private fun proprieteSysteme(nom: String): String = runCatching {
        Class.forName("android.os.SystemProperties").getMethod("get", String::class.java).invoke(null, nom) as String
    }.getOrDefault("")

    private fun etat(): Map<String, Any> = mapOf(
        "chaleur" to chaleur,
        "economie" to puissance.isPowerSaveMode,
        "petitTelephone" to petitTelephone(),
        "lentille" to lentillePossible,
    )

    private fun signaler() {
        appliquerFrequence()
        canal?.invokeMethod("changement", etat())
    }

    // L ecran le plus rapide (90, 120 Hz), meme quand le telephone chauffe ;
    // seul l economiseur de batterie le laisse au mode choisi par le systeme.
    private fun appliquerFrequence() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        val ecran = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) display else @Suppress("DEPRECATION") windowManager.defaultDisplay
        ecran ?: return
        val leger = puissance.isPowerSaveMode
        val actuel = ecran.mode
        val mode = if (leger) 0 else ecran.supportedModes
            .filter { it.physicalWidth == actuel.physicalWidth && it.physicalHeight == actuel.physicalHeight }
            .maxByOrNull { it.refreshRate }?.modeId ?: 0
        val attributs = window.attributes
        if (attributs.preferredDisplayModeId == mode) return
        attributs.preferredDisplayModeId = mode
        window.attributes = attributs
    }
}
