import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  /// Handles `.pensine` files opened via Finder double-click, Dock drop,
  /// `open -a Pensine <file>`, or the default-app association. Mirrors the
  /// iOS `SceneDelegate.writeIncomingURL` handoff: bytes go to
  /// `NSTemporaryDirectory()/pensine_incoming.pensine`, where the Dart-side
  /// `pending_import_native.dart` polls on launch + resume. Works in both
  /// sandboxed (MAS) and non-sandboxed (Developer ID DMG) builds — under
  /// the sandbox the Powerbox grants temporary read access to any file the
  /// user hands off via Finder, so no extra entitlement beyond the
  /// document-type declaration is required.
  override func application(_ application: NSApplication, open urls: [URL]) {
    for url in urls {
      writeIncomingURL(url)
    }
  }

  /// Legacy path for older callers that still dispatch `openFile(s)`
  /// (NSWorkspace's `open -a` under some configurations, Dock targets for
  /// pre-modern document types). Routes into the same handoff.
  override func application(_ sender: NSApplication, openFiles paths: [String]) {
    for path in paths {
      writeIncomingURL(URL(fileURLWithPath: path))
    }
    sender.reply(toOpenOrPrint: .success)
  }

  private func writeIncomingURL(_ url: URL) {
    let didAccess = url.startAccessingSecurityScopedResource()
    defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
    guard let data = try? Data(contentsOf: url) else { return }

    // Match what Dart's `getTemporaryDirectory()` returns on macOS:
    // `<caches>/<bundle-id>/` — NOT `NSTemporaryDirectory()` (which is the
    // iOS convention and resolves to a different path on macOS). The
    // bundle-id subdir isn't auto-created until something writes into it,
    // so ensure it exists before the write.
    guard let cachesDir = try? FileManager.default.url(
      for: .cachesDirectory,
      in: .userDomainMask,
      appropriateFor: nil,
      create: true
    ) else { return }
    let bundleId = Bundle.main.bundleIdentifier ?? "com.frenchcommando.pensine"
    let targetDir = cachesDir.appendingPathComponent(bundleId)
    try? FileManager.default.createDirectory(
      at: targetDir, withIntermediateDirectories: true
    )
    let target = targetDir.appendingPathComponent("pensine_incoming.pensine")
    try? data.write(to: target)
  }
}
