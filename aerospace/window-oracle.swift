// Minimized-but-still-tiled detector for reap-ghosts.sh.
//
// Usage:  window-oracle <candidate-window-id ...>
// Output: the candidates that are minimized phantoms, space-separated.
//
// AeroSpace window-ids ARE CGWindowIDs. A candidate must fail BOTH independent
// checks — kCGWindowIsOnscreen == false in the window server AND
// kAXMinimizedAttribute == true via AX — before it is named. Anything less
// prints nothing for that id: this tool errs toward false negatives, never
// false positives, because a detector's failure mode must be inaction (the
// 2026-07-29 incident, docs/aerospace/RETILE-DELAY.md). A nil or empty window
// list means "oracle broken", never "no windows exist": exit 1. Missing AX
// permission: exit 2. Either way nothing prints, so a consumer cannot mistake
// "cannot ask" for an answer.
import ApplicationServices
import AppKit

@_silgen_name("_AXUIElementGetWindow")
func _AXUIElementGetWindow(_ element: AXUIElement, _ wid: inout CGWindowID) -> AXError

guard let wl = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]],
      !wl.isEmpty else {
    FileHandle.standardError.write(Data("window-oracle: window server gave nil/empty list — oracle unusable in this context\n".utf8))
    exit(1)
}
guard AXIsProcessTrusted() else {
    FileHandle.standardError.write(Data("window-oracle: no accessibility permission in this context\n".utf8))
    exit(2)
}

var onscreen = Set<CGWindowID>()
for w in wl {
    if let num = w["kCGWindowNumber"] as? Int, let on = w["kCGWindowIsOnscreen"] as? Bool, on {
        onscreen.insert(CGWindowID(num))
    }
}

var remaining = Set(CommandLine.arguments.dropFirst().compactMap { CGWindowID($0) }.filter { !onscreen.contains($0) })
var phantoms: [CGWindowID] = []
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
            phantoms.append(num)
        }
        remaining.remove(num)
    }
}
print(phantoms.map(String.init).joined(separator: " "))
