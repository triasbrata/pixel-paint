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

  /// Keeps the game to one copy. When it's already open, brings that copy to
  /// the front and returns true: this one should quit before the game starts.
  ///
  /// `flutter run` starts the app's binary directly and then `open`s the
  /// bundle to bring it forward, which macOS answers with a second copy. The
  /// copy `flutter run` started (it passes engine switches in the
  /// environment) always stays, so hot reload keeps its window.
  static func handOffToRunningCopy() -> Bool {
    if ProcessInfo.processInfo.environment["FLUTTER_ENGINE_SWITCHES"] != nil { return false }
    let me = ProcessInfo.processInfo.processIdentifier
    guard let id = Bundle.main.bundleIdentifier,
          let other = NSRunningApplication.runningApplications(withBundleIdentifier: id)
            .first(where: { $0.processIdentifier != me && !$0.isTerminated })
    else { return false }
    if #available(macOS 14.0, *) {
      NSApp.yieldActivation(to: other)
      other.activate()
    } else {
      other.activate(options: .activateIgnoringOtherApps)
    }
    return true
  }
}
