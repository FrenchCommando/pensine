package com.frenchcommando.pensine

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import java.io.File

class MainActivity : FlutterActivity() {
  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    captureIntent(intent)
  }

  override fun onNewIntent(intent: Intent) {
    super.onNewIntent(intent)
    setIntent(intent)
    captureIntent(intent)
  }

  private fun captureIntent(intent: Intent?) {
    if (intent == null) return
    val uri: Uri = when (intent.action) {
      Intent.ACTION_VIEW -> intent.data ?: return
      Intent.ACTION_SEND -> extractStream(intent) ?: return
      else -> return
    }
    try {
      contentResolver.openInputStream(uri)?.use { input ->
        val target = File(cacheDir, "pensine_incoming.pensine")
        target.outputStream().use { output -> input.copyTo(output) }
      }
    } catch (_: Exception) {
      // Swallow — Dart side shows "not a valid .pensine" if the file is unreadable.
    }
  }

  private fun extractStream(intent: Intent): Uri? {
    return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
      intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
    } else {
      @Suppress("DEPRECATION")
      intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
    }
  }
}
