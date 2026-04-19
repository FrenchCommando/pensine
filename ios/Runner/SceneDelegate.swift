import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {

  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    for ctx in connectionOptions.urlContexts {
      writeIncomingURL(ctx.url)
    }
    super.scene(scene, willConnectTo: session, options: connectionOptions)
  }

  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    for ctx in URLContexts {
      writeIncomingURL(ctx.url)
    }
    super.scene(scene, openURLContexts: URLContexts)
  }

  private func writeIncomingURL(_ url: URL) {
    let didAccess = url.startAccessingSecurityScopedResource()
    defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
    guard let data = try? Data(contentsOf: url) else { return }
    let target = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("pensine_incoming.pensine")
    try? data.write(to: target)
  }
}
