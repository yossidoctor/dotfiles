// Window-server + AX oracle for reap-ghosts.sh and diagnose-gap.sh. One
// process, one CGWindowListCopyWindowInfo read, both verdicts — so the ghost
// answer and the phantom answer describe the same instant and cannot
// disagree about which windows existed.
//
// Usage:  window-oracle [candidate-window-id ...]
// Output: "ALL <id> <id> ..."       every window id the server knows
//         "PHANTOM <id> <id> ..."   candidates that are minimized phantoms
// Both lines always print, PHANTOM possibly empty. Consumers read the line
// they need; an absent line means this tool failed and nothing is trusted.
//
// ALL is the ghost oracle (upstream #1615): AeroSpace window-ids ARE
// CGWindowIDs, so a tree id absent from ALL is a ghost CANDIDATE — never
// proof by itself. .optionAll on purpose, all layers, on- and off-screen: a
// superset cannot create a false ghost, and consumers only test membership.
// CONTRACT: a nil or empty window list means "oracle broken", NEVER "no
// windows exist" — it exits 1 with a stderr line and prints no ALL line. The
// 2026-07-29 incident (docs/aerospace/RETILE-DELAY.md) happened because an
// empty list read as universal window death and four live windows were
// closed.
//
// PHANTOM is the minimized-but-still-tiled detector. A candidate must fail
// BOTH independent checks — kCGWindowIsOnscreen == false in the window
// server AND kAXMinimizedAttribute == true via AX — before it is named.
// Anything less prints nothing for that id: this tool errs toward false
// negatives, never false positives, because a detector's failure mode must
// be inaction (same incident). Missing AX permission is loud: exit 2, no
// PHANTOM line, so a consumer cannot mistake "cannot ask" for "none found".
//
// The onscreen set comes from the same .optionAll read as ALL, filtered on
// kCGWindowIsOnscreen, rather than a second .optionOnScreenOnly call.
import ApplicationServices
import AppKit

@_silgen_name("_AXUIElementGetWindow")
func _AXUIElementGetWindow(_ element: AXUIElement, _ wid: inout CGWindowID) -> AXError

guard let wl = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]],
      !wl.isEmpty else {
    FileHandle.standardError.write(Data("window-oracle: window server gave nil/empty list — oracle unusable in this context\n".utf8))
    exit(1)
}

var all: [CGWindowID] = []
var onscreen = Set<CGWindowID>()
for w in wl {
    guard let num = w["kCGWindowNumber"] as? Int else { continue }
    let id = CGWindowID(num)
    all.append(id)
    if let on = w["kCGWindowIsOnscreen"] as? Bool, on { onscreen.insert(id) }
}
print("ALL " + all.map(String.init).joined(separator: " "))

let candidates = CommandLine.arguments.dropFirst().compactMap { CGWindowID($0) }
if candidates.isEmpty {
    print("PHANTOM")
    exit(0)
}
guard AXIsProcessTrusted() else {
    FileHandle.standardError.write(Data("window-oracle: no accessibility permission in this context\n".utf8))
    exit(2)
}

var remaining = Set(candidates.filter { !onscreen.contains($0) })
var phantoms: [CGWindowID] = []
if !remaining.isEmpty {
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
}
print("PHANTOM " + phantoms.map(String.init).joined(separator: " "))
