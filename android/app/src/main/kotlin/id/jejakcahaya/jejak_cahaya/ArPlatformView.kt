package id.jejakcahaya.jejak_cahaya

import android.content.Context
import android.content.ContextWrapper
import android.util.Log
import android.view.View
import androidx.activity.ComponentActivity
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.produceState
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.ComposeView
import androidx.compose.ui.platform.ViewCompositionStrategy
import androidx.compose.ui.unit.dp
import androidx.lifecycle.setViewTreeLifecycleOwner
import androidx.lifecycle.setViewTreeViewModelStoreOwner
import androidx.savedstate.setViewTreeSavedStateRegistryOwner
import io.flutter.FlutterInjector
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import io.github.sceneview.ar.ARCoreAvailability
import io.github.sceneview.ar.AutoPlacementNode
import io.github.sceneview.ar.AutoPlacementScene
import io.github.sceneview.ar.PlacementPhase
import io.github.sceneview.ar.rememberAutoPlacementState
import io.github.sceneview.math.Position
import io.github.sceneview.model.ModelInstance
import io.github.sceneview.model.model
import io.github.sceneview.rememberEngine
import io.github.sceneview.rememberModelLoader
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.flow.distinctUntilChanged

/**
 * Model yang dibundel di APK datang sebagai kunci aset Flutter
 * (`assets/models/soekarno.glb`) dan diterjemahkan ke jalur di AssetManager
 * (`flutter_assets/assets/models/soekarno.glb`) — jalur tanpa skema yang dibaca
 * SceneView langsung dari APK, tanpa disalin ke penyimpanan lebih dulu.
 * Model unduhan datang sebagai `file://`.
 */
private fun resolveModelLocation(params: Map<String, Any?>): String {
    val assetKey = params["assetKey"] as? String
    if (!assetKey.isNullOrEmpty()) {
        return FlutterInjector.instance().flutterLoader().getLookupKeyForAsset(assetKey)
    }
    return params["modelLocation"] as? String ?: ""
}

class ArPlatformViewFactory(
    private val messenger: BinaryMessenger,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        @Suppress("UNCHECKED_CAST")
        val params = args as? Map<String, Any?> ?: emptyMap()
        return ArPlatformView(
            context = context,
            modelLocation = resolveModelLocation(params),
            bottomInsetDp = (params["bottomInsetDp"] as? Number)?.toFloat() ?: 0f,
            animationChoice = params["animation"] as? String,
            events = MethodChannel(messenger, "${ArPlatformView.VIEW_TYPE}/$viewId"),
        )
    }
}

/**
 * Kamera AR dengan satu tokoh yang otomatis berdiri di lantai pertama yang
 * terdeteksi.
 *
 * Seluruh penjelasan tokoh, tombol, dan galat digambar Flutter di atas view
 * ini; yang dikerjakan di sini hanya AR-nya. Kejadian penting dikabarkan lewat
 * [events] supaya Flutter bisa menyesuaikan tampilannya:
 *  - `placed`         — tokoh sudah berdiri di lantai.
 *  - `modelFailed`    — berkas GLB tidak bisa dibaca.
 *  - `unsupported`    — ternyata perangkat tidak bisa menjalankan ARCore.
 *  - `sessionFailed`  — sesi AR gagal dimulai (kamera dipakai aplikasi lain, dsb.).
 *  - `modelLoaded`    — berkas GLB selesai diurai dan siap ditaruh.
 *  - `phase`          — tahap AR berganti (`phase`: nama [PlacementPhase],
 *                       `camera`: sudah ada gambar kamera atau belum). Dipakai
 *                       Flutter untuk menampilkan status dan, bila kamera tak
 *                       pernah memberi gambar, beralih ke tampilan 3D.
 */
class ArPlatformView(
    context: Context,
    private val modelLocation: String,
    private val bottomInsetDp: Float,
    /**
     * Pilihan animasi dari panel admin — lihat [resolveAnimation]. Sengaja
     * bukan `animation`: di dalam `ComposeView.apply { }` nama itu tertangkap
     * sebagai `View.animation` milik Android.
     */
    private val animationChoice: String?,
    private val events: MethodChannel,
) : PlatformView {

    private val composeView = ComposeView(context).apply {
        // Pemilik lifecycle dipasang langsung dari activity alih-alih dicari
        // ComposeView di view induknya. Flutter menitipkan platform view di
        // dalam pembungkusnya sendiri, dan bila pencarian itu meleset ComposeView
        // melempar galat — sementara sesi ARCore justru bergantung pada lifecycle
        // ini untuk tahu kapan kamera dijeda dan dilanjutkan.
        context.findComponentActivity()?.let { activity ->
            setViewTreeLifecycleOwner(activity)
            setViewTreeSavedStateRegistryOwner(activity)
            setViewTreeViewModelStoreOwner(activity)
        }
        // Komposisi dilepas di dispose(), yang dipanggil Flutter saat widget
        // AR-nya keluar dari layar.
        setViewCompositionStrategy(ViewCompositionStrategy.DisposeOnDetachedFromWindow)
        setContent {
            TokohArScene(
                modelLocation = modelLocation,
                bottomInsetDp = bottomInsetDp,
                animation = animationChoice,
                onEvent = ::emit,
            )
        }
    }

    private fun emit(name: String, payload: Map<String, Any?> = emptyMap()) {
        try {
            events.invokeMethod(name, payload)
        } catch (error: Exception) {
            Log.w(TAG, "Gagal mengabarkan $name ke Flutter", error)
        }
    }

    override fun getView(): View = composeView

    override fun dispose() {
        composeView.disposeComposition()
    }

    companion object {
        const val VIEW_TYPE = "id.jejakcahaya/ar_view"
        private const val TAG = "JejakAr"
    }
}

/** Context dari Flutter bisa berupa pembungkus; telusuri sampai activity-nya. */
private tailrec fun Context.findComponentActivity(): ComponentActivity? = when (this) {
    is ComponentActivity -> this
    is ContextWrapper -> baseContext.findComponentActivity()
    else -> null
}

/** Hasil memuat model: dibedakan antara "masih dimuat" dan "gagal". */
private sealed interface ModelLoad {
    data object Loading : ModelLoad
    data class Ready(val instance: ModelInstance) : ModelLoad
    data object Failed : ModelLoad
}

@Composable
private fun TokohArScene(
    modelLocation: String,
    bottomInsetDp: Float,
    animation: String?,
    onEvent: (String, Map<String, Any?>) -> Unit,
) {
    val engine = rememberEngine()
    val modelLoader = rememberModelLoader(engine)
    val placementState = rememberAutoPlacementState()

    // Dimuat sendiri, bukan lewat `rememberModelInstance`: fungsi itu
    // mengembalikan null baik saat masih memuat maupun saat gagal, sehingga
    // berkas yang rusak membuat pemain menunggu selamanya.
    val load by produceState<ModelLoad>(ModelLoad.Loading, modelLoader, modelLocation) {
        value = try {
            modelLoader.loadModelInstance(modelLocation)
                ?.let { ModelLoad.Ready(it) }
                ?: ModelLoad.Failed
        } catch (cancelled: CancellationException) {
            throw cancelled
        } catch (error: Exception) {
            Log.w("JejakAr", "Model tidak bisa dimuat: $modelLocation", error)
            ModelLoad.Failed
        }
        if (value == ModelLoad.Failed) onEvent("modelFailed", emptyMap())
        if (value is ModelLoad.Ready) onEvent("modelLoaded", emptyMap())
    }

    LaunchedEffect(placementState) {
        snapshotFlow { placementState.phase to placementState.hasCameraFrame }
            .distinctUntilChanged()
            .collect { (phase, camera) ->
                onEvent("phase", mapOf("phase" to phase.name, "camera" to camera))
            }
    }

    val instance = (load as? ModelLoad.Ready)?.instance
    DisposableEffect(instance) {
        onDispose { instance?.let { modelLoader.destroyModel(it.model) } }
    }

    AutoPlacementScene(
        assetReady = instance != null,
        modifier = Modifier.fillMaxSize(),
        state = placementState,
        engine = engine,
        modelLoader = modelLoader,
        // Panduan "gerakkan ponsel" milik SceneView dipakai apa adanya —
        // teksnya sudah diterjemahkan di res/values/strings.xml — tetapi digeser
        // ke atas supaya tidak tertutup lembar penjelasan tokoh di Flutter.
        coachingContentPadding = PaddingValues(bottom = bottomInsetDp.dp),
        onARCoreAvailability = { availability ->
            if (availability == ARCoreAvailability.Unsupported) {
                onEvent("unsupported", emptyMap())
            }
        },
        onSessionFailed = { error ->
            onEvent("sessionFailed", mapOf("message" to (error.message ?: error.javaClass.simpleName)))
        },
        onPlaced = { onEvent("placed", emptyMap()) },
    ) { placement ->
        if (instance != null) {
            // AutoPlacementNode + ModelNode sendiri, bukan AutoPlacementModel:
            // yang terakhir membuat ModelNode dengan autoAnimate, yang memutar
            // SEMUA animasi di berkas sekaligus — pilihan animasi dari panel
            // admin tidak akan pernah terlihat.
            AutoPlacementNode(placement = placement, state = placementState) {
                ModelNode(
                    modelInstance = instance,
                    autoAnimate = false,
                    animationName = resolveAnimation(instance, animation),
                    // Ukuran asli berkasnya (placeholder: 1,7 m), jadi tokoh
                    // berdiri setinggi manusia. Kakinya di titik kontak lantai.
                    scaleToUnits = null,
                    centerOrigin = Position(x = 0f, y = -1f, z = 0f),
                    // Dapat dipilih supaya cubit & putar dua jari sampai ke pivot
                    // penempatan, tetapi tidak menggeser dirinya sendiri.
                    isEditable = true,
                    apply = {
                        isPositionEditable = false
                        isRotationEditable = false
                        isScaleEditable = false
                    },
                )
            }
        }
    }
}

/**
 * Nama animasi yang diputar, dari pilihan admin (`modelAnimation`):
 * - `null`/kosong → animasi pertama di berkas;
 * - `@none`       → diam;
 * - selain itu    → nama itu, bila memang ada; kalau tidak, animasi pertama
 *   (lebih baik tokoh bergerak daripada diam karena salah ketik).
 */
private fun resolveAnimation(instance: ModelInstance, choice: String?): String? {
    if (choice == ANIMATION_NONE) return null
    val animator = instance.animator
    val names = (0 until animator.animationCount).map { animator.getAnimationName(it) }
    if (names.isEmpty()) return null
    return choice?.takeIf { it.isNotBlank() && it in names } ?: names.first()
}

private const val ANIMATION_NONE = "@none"
