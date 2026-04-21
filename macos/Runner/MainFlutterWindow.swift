import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController
    // Pin the whole window frame (title bar included) to 1440x900 so that
    // `screencapture -l <windowID>` produces a Mac App Store-accepted
    // size directly (Retina renders at 2880x1800, also accepted). XIB's
    // contentRect alone doesn't survive Flutter's engine init — this is
    // the reliable override after the view controller attaches.
    var newFrame = self.frame
    newFrame.size = NSSize(width: 1440, height: 900)
    self.setFrame(newFrame, display: true)
    // Flutter drive's app spawn leaves the window inactive (traffic
    // lights grey, layout ambiguous). Force activation so the window
    // becomes key and screenshots capture a focused app window. Normal
    // macOS launch behavior; no UX regression for real users.
    self.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
