// Phantom-tile detector for reap-ghosts.sh and diagnose-gap.sh. A "phantom
// tile" is a window AeroSpace still tiles into a slot while macOS has it
// minimized — on Tahoe AeroSpace's native-minimize detection can stall for
// minutes (upstream #1615), leaving an invisible slot: the on-screen gap is
// the minimized window's tile. Args: candidate CGWindowIDs (= AeroSpace
// window-ids) from a VISIBLE workspace. Prints only ids that fail BOTH
// independent checks: kCGWindowIsOnscreen == false in the window server AND
// kAXMinimizedAttribute == true via AX. Anything less than both signals
// prints nothing — consumers treat "no output" as "no phantoms", so this
// tool errs toward false negatives, never false positives (2026-07-29
// incident lesson: a detector's failure mode must be inaction). Exits 2
// loud if AX permission is missing in the calling context.
import ApplicationServices
import AppKit

@_silgen_name("_AXUIElementGetWindow")
func _AXUIElementGetWindow(_ element: AXUIElement, _ wid: inout CGWindowID) -> AXError

let candidates = CommandLine.arguments.dropFirst().compactMap { CGWindowID($0) }
if candidates.isEmpty { exit(0) }
guard AXIsProcessTrusted() else {
    FileHandle.standardError.write(Data("phantom-check: no accessibility permission in this context\n".utf8))
    exit(2)
}

var onscreen = Set<CGWindowID>()
if let wl = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] {
    for w in wl {
        if let num = w["kCGWindowNumber"] as? Int { onscreen.insert(CGWindowID(num)) }
    }
}
let offscreen = candidates.filter { !onscreen.contains($0) }
if offscreen.isEmpty { exit(0) }

var remaining = Set(offscreen)
for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
    if remaining.isEmpty { break }
    let axApp = AXUIElementCreateApplication(app.processIdentifier)
    var winsRef: CFTypeRef?
    guard AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &winsRef) == .success,
          let wins = winsRef as? [AXUIElement] else { continue }
    for w in wins {
        var num = CGWindowID(0)
        guard _AXUIElementGetWindow(w, &num) == .success, remaining.contains(num) else { continue }
        var minRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(w, kAXMinimizedAttribute as CFString, &minRef) == .success,
           minRef as? Bool == true {
            print(num)
        }
        remaining.remove(num)
    }
}
