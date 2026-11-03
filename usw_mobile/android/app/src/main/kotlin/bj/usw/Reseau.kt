package bj.usw

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Le reseau du telephone (lib/outils/reseau.dart) : connecte ou non, et facture a l usage
 * (donnees mobiles, partage de connexion) ou non (Wi-Fi). Chaque changement est signale.
 */
class Reseau(contexte: Context, private val canal: MethodChannel) : MethodChannel.MethodCallHandler {
    private val connexions = contexte.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
    private val principal = Handler(Looper.getMainLooper())

    private val ecoute = object : ConnectivityManager.NetworkCallback() {
        override fun onAvailable(reseau: Network) = signaler()
        override fun onLost(reseau: Network) = signaler()
        override fun onCapabilitiesChanged(reseau: Network, capacites: NetworkCapabilities) = signaler()
    }

    fun demarrer() {
        runCatching { connexions.registerDefaultNetworkCallback(ecoute) }
    }

    fun arreter() {
        runCatching { connexions.unregisterNetworkCallback(ecoute) }
    }

    override fun onMethodCall(appel: MethodCall, resultat: MethodChannel.Result) {
        if (appel.method == "etat") resultat.success(etat()) else resultat.notImplemented()
    }

    private fun etat(): Map<String, Boolean> {
        val capacites = connexions.getNetworkCapabilities(connexions.activeNetwork)
        val connecte = capacites?.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) == true
        return mapOf("connecte" to connecte, "limite" to (connecte && connexions.isActiveNetworkMetered))
    }

    private fun signaler() {
        principal.post { canal.invokeMethod("change", etat()) }
    }
}
