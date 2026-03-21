import AppKit
import SwiftUI

// When launched as an SPM executable (not from an .app bundle), macOS assigns
// "background" activation policy by default — no Dock icon, no windows.
// Explicitly setting .regular before the SwiftUI run loop starts fixes this.
let app = NSApplication.shared
app.setActivationPolicy(.regular)

RoxProxyApp.main()
