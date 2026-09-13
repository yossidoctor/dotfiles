// Raise one window (by CGWindowID = AeroSpace window-id, argv[1]) to the top
// of the global z-order: kAXMainAttribute on, kAXRaiseAction on the window,
// then activate its app — the same sequence AeroSpace's own
// MacApp.nativeFocus performs, which is the ONLY raise anywhere in
// AeroSpace and fires only when focus changes. (nativeFocus passes
// .activateIgnoringOtherApps, a no-op on macOS 14+ per the SDK deprecation
// note.)
// Needed because AeroSpace's fake `fullscreen` never manages z-order (its
// layout pass sets frames only), so a fullscreen window buried by a sibling
// raise stays buried — see raise-fullscreen.sh for when this runs. AXRaise
// alone reorders only within the window's own app; the activate step is
// what beats other apps' z-bands. Raise/activate only — this binary must
// never close, kill, or minimize anything (2026-07-29 incident invariant,
// docs/aerospace/RETILE-DELAY.md). Exits loud (message + nonzero) on missing permission or
// unfound id so callers can't mistake failure for success.
import ApplicationServices
import AppKit

@_silgen_name("_AXUIElementGetWindow")
func _AXUIElementGetWindow(_ element: AXUIElement, _ wid: inout CGWindowID) -> AXError

guard CommandLine.arguments.count > 1, let target = CGWindowID(CommandLine.arguments[1]) else {
    FileHandle.standardError.write(Data("usage: raise-window <window-id>\n".utf8))
    exit(2)
}
guard AXIsProcessTrusted() else {
    FileHandle.standardError.write(Data("raise-window: no accessibility permission in this context\n".utf8))
    exit(2)
}

for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
    let axApp = AXUIElementCreateApplication(app.processIdentifier)
    var winsRef: CFTypeRef?
    guard AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &winsRef) == .success,
          let wins = winsRef as? [AXUIElement] else { continue }
    for w in wins {
        var num = CGWindowID(0)
        guard _AXUIElementGetWindow(w, &num) == .success, num == target else { continue }
        AXUIElementSetAttributeValue(w, kAXMainAttribute as CFString, kCFBooleanTrue)
        let raiseErr = AXUIElementPerformAction(w, kAXRaiseAction as CFString)
        let activated = app.activate()
        if raiseErr == .success && activated {
            exit(0)
        }
        FileHandle.standardError.write(Data("raise-window: raise=\(raiseErr.rawValue) activate=\(activated)\n".utf8))
        exit(1)
    }
}
FileHandle.standardError.write(Data("raise-window: window \(target) not found via AX\n".utf8))
exit(1)
