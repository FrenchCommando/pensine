import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    var windowFrame = self.frame
    // Screenshot-mode window pinning: `PENSINE_WINDOW_SIZE=1440x900` sets the
    // window to a Mac-App-Store-accepted point size (1280x800, 1440x900,
    // 2560x1600, 2880x1800). On Retina, 1440 points → 2880 pixels; on
    // non-Retina, 1440 points → 1440 pixels. Either way the screencapture
    // output lands on an accepted size. Only the Artifacts workflow sets
    // this — normal launches use the scaffold default.
    if let sizeStr = ProcessInfo.processInfo.environment["PENSINE_WINDOW_SIZE"] {
      let parts = sizeStr.split(separator: "x").compactMap { Int($0) }
      if parts.count == 2 {
        windowFrame.size = NSSize(width: parts[0], height: parts[1])
      }
    }
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
