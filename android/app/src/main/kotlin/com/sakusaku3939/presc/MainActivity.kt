package com.sakusaku3939.presc

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class MainActivity: FlutterActivity() {
    private val channelName = "com.sakusaku3939.presc/saf_vault"
    private val pickVaultRequestCode = 4601
    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    private lateinit var safVaultService: SafVaultService
    private var pendingPickResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        safVaultService = SafVaultService(applicationContext)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "pickVault" -> pickVault(result)
                "getVaultName" -> runInBackground(result) {
                    safVaultService.getDisplayName(requireUri(call.argument("treeUri")))
                }
                "listDocuments" -> runInBackground(result) {
                    safVaultService.listDocuments(requireUri(call.argument("treeUri")))
                }
                "readDocument" -> runInBackground(result) {
                    safVaultService.readText(requireUri(call.argument("uri")))
                }
                "writeDocument" -> runInBackground(result) {
                    val uri = requireUri(call.argument("uri"))
                    val content = call.argument<String>("content")
                        ?: throw IllegalArgumentException("content is required")
                    safVaultService.writeText(uri, content)
                    true
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun pickVault(result: MethodChannel.Result) {
        if (pendingPickResult != null) {
            result.error("picker_busy", "The folder picker is already open.", null)
            return
        }

        pendingPickResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
            addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
            addFlags(Intent.FLAG_GRANT_PREFIX_URI_PERMISSION)
        }
        startActivityForResult(intent, pickVaultRequestCode)
    }

    @Deprecated("Deprecated in Android, retained for Flutter plugin compatibility")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != pickVaultRequestCode) return

        val result = pendingPickResult ?: return
        pendingPickResult = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(null)
            return
        }

        try {
            val offeredFlags = data.flags and (
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                )
            contentResolver.takePersistableUriPermission(uri, offeredFlags)
            result.success(
                mapOf(
                    "treeUri" to uri.toString(),
                    "displayName" to safVaultService.getDisplayName(uri),
                    "canWrite" to (offeredFlags and Intent.FLAG_GRANT_WRITE_URI_PERMISSION != 0),
                ),
            )
        } catch (error: Exception) {
            result.error("persist_permission_failed", error.message, null)
        }
    }

    private fun requireUri(value: String?): Uri {
        if (value.isNullOrBlank()) throw IllegalArgumentException("uri is required")
        return Uri.parse(value)
    }

    private fun runInBackground(result: MethodChannel.Result, block: () -> Any?) {
        executor.execute {
            try {
                val value = block()
                mainHandler.post { result.success(value) }
            } catch (error: Exception) {
                mainHandler.post {
                    result.error("saf_error", error.message ?: error.javaClass.simpleName, null)
                }
            }
        }
    }

    override fun onDestroy() {
        executor.shutdown()
        super.onDestroy()
    }
}
