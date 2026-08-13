import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    // Autostart (LaunchAgent) — canal "tether/autostart".
    FlutterMethodChannel(
      name: "tether/autostart",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    ).setMethodCallHandler { call, result in
      switch call.method {
      case "isEnabled":
        result(TetherAutostart.isEnabled)
      case "setEnabled":
        if let args = call.arguments as? [String: Any],
           let enabled = args["enabled"] as? Bool {
          TetherAutostart.setEnabled(enabled)
          result(nil)
        } else {
          result(FlutterError(
            code: "bad_args",
            message: "expected 'enabled' bool",
            details: nil
          ))
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    super.awakeFromNib()
  }
}

/// Registra o elimina un LaunchAgent para arrancar al iniciar sesión.
enum TetherAutostart {
  private static var plistURL: URL {
    FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent("Library/LaunchAgents")
      .appendingPathComponent("com.tether.app.plist")
  }

  private static var executablePath: String {
    Bundle.main.executablePath ?? "/usr/bin/true"
  }

  static var isEnabled: Bool {
    FileManager.default.fileExists(atPath: plistURL.path)
  }

  static func setEnabled(_ enabled: Bool) {
    let url = plistURL
    let dir = url.deletingLastPathComponent()
    do {
      if enabled {
        try FileManager.default.createDirectory(
          at: dir, withIntermediateDirectories: true)
        let plist: [String: Any] = [
          "Label": "com.tether.app",
          "ProgramArguments": [executablePath],
          "RunAtLoad": true,
        ]
        let data = try PropertyListSerialization.data(
          fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: url, options: .atomic)
      } else if FileManager.default.fileExists(atPath: url.path) {
        try FileManager.default.removeItem(at: url)
      }
    } catch {
      // best-effort
    }
  }
}
