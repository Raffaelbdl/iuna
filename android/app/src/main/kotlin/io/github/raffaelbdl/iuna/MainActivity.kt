package io.github.raffaelbdl.iuna

import android.content.Intent
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "io.github.raffaelbdl.iuna/update",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "installApk" -> try {
                    val apk = File(call.argument<String>("path")!!)
                    val uri = FileProvider.getUriForFile(
                        this, "$packageName.updates", apk,
                    )
                    // The installer asks for "Install unknown apps" itself
                    // the first time, then shows its own confirm dialog.
                    startActivity(
                        Intent(Intent.ACTION_VIEW)
                            .setDataAndType(uri, "application/vnd.android.package-archive")
                            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION),
                    )
                    result.success(null)
                } catch (e: Exception) {
                    result.error("install", e.message, null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
