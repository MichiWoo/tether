import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    // La app vive en la bandeja del sistema: no termina al cerrar la ventana.
    return false
  }
}
