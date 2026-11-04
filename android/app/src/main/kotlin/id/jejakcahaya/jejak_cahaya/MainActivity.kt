package id.jejakcahaya.jejak_cahaya

import com.google.ar.core.ArCoreApk
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * FlutterFragmentActivity, bukan FlutterActivity: layar AR tokoh dibangun dengan
 * Jetpack Compose (satu-satunya API SceneView), dan ComposeView butuh
 * LifecycleOwner + SavedStateRegistryOwner yang hanya disediakan
 * `ComponentActivity`. FlutterActivity bukan turunannya — dengan itu ComposeView
 * langsung melempar galat begitu ditempelkan, dan sesi ARCore tidak pernah
 * tahu kapan harus jeda atau lanjut.
 */
class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val messenger = flutterEngine.dartExecutor.binaryMessenger

        flutterEngine.platformViewsController.registry.registerViewFactory(
            ArPlatformView.VIEW_TYPE,
            ArPlatformViewFactory(messenger),
        )

        MethodChannel(messenger, CAPABILITY_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkAvailability" -> checkArAvailability(result)
                else -> result.notImplemented()
            }
        }
    }

    /**
     * Menanyakan ARCore apakah perangkat ini bisa menjalankan AR.
     *
     * Versi async, bukan `checkAvailability()` biasa: yang sinkron bisa memblokir
     * thread utama cukup lama untuk memicu ANR saat Google Play Services for AR
     * belum pernah ditanya di perangkat itu.
     *
     * "Didukung tetapi belum terpasang" tetap dilaporkan `supported`: layar AR
     * SceneView sendiri yang menawarkan pemasangannya, dan itu jauh lebih baik
     * daripada diam-diam turun ke tampilan 3D biasa.
     */
    private fun checkArAvailability(result: MethodChannel.Result) {
        try {
            ArCoreApk.getInstance().checkAvailabilityAsync(this) { availability ->
                val value = when {
                    availability.isSupported -> "supported"
                    availability.isUnknown -> "unknown"
                    else -> "unsupported"
                }
                runOnUiThread { result.success(value) }
            }
        } catch (error: Exception) {
            result.success("unsupported")
        }
    }

    private companion object {
        const val CAPABILITY_CHANNEL = "id.jejakcahaya/ar_capability"
    }
}
