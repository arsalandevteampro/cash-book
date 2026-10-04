package com.arsalandev.cashbook

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import androidx.activity.enableEdgeToEdge
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "com.arsalandev.cashbook/whatsapp_launcher"

    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "openWhatsAppChooser" -> {
                    val phone = call.argument<String>("phone") ?: ""
                    val message = call.argument<String>("message") ?: ""
                    val title = call.argument<String>("title") ?: "Open with"

                    try {
                        val uri = Uri.parse("https://api.whatsapp.com/send?phone=$phone&text=${Uri.encode(message)}")
                        val targetIntents = mutableListOf<Intent>()

                        // Check if regular WhatsApp is installed
                        try {
                            packageManager.getPackageInfo("com.whatsapp", 0)
                            targetIntents.add(Intent(Intent.ACTION_VIEW, uri).apply {
                                setPackage("com.whatsapp")
                            })
                        } catch (_: Exception) {}

                        // Check if WhatsApp Business is installed
                        try {
                            packageManager.getPackageInfo("com.whatsapp.w4b", 0)
                            targetIntents.add(Intent(Intent.ACTION_VIEW, uri).apply {
                                setPackage("com.whatsapp.w4b")
                            })
                        } catch (_: Exception) {}

                        if (targetIntents.size >= 2) {
                            // Both installed: show system chooser with only WhatsApp & WhatsApp Business
                            val chooser = Intent.createChooser(targetIntents[0], title)
                            chooser.putExtra(
                                Intent.EXTRA_INITIAL_INTENTS,
                                targetIntents.subList(1, targetIntents.size).toTypedArray()
                            )
                            startActivity(chooser)
                            result.success(true)
                        } else if (targetIntents.size == 1) {
                            // Only one installed: launch directly
                            startActivity(targetIntents[0])
                            result.success(true)
                        } else {
                            // Fallback to web URL
                            val webUri = Uri.parse("https://wa.me/$phone?text=${Uri.encode(message)}")
                            val webIntent = Intent(Intent.ACTION_VIEW, webUri)
                            startActivity(webIntent)
                            result.success(true)
                        }
                    } catch (e: Exception) {
                        result.error("LAUNCH_FAILED", e.message, null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
