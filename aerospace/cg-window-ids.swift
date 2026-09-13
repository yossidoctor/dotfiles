// Print every window id (kCGWindowNumber) the macOS window server knows,
// one per line — all layers, all displays, on- and off-screen. Ground-truth
// existence oracle for reap-ghosts.sh and diagnose-gap.sh: AeroSpace
// window-ids ARE CGWindowIDs, so a tree id absent here is a ghost CANDIDATE
// — never proof by itself. Contract with consumers: oracle failure (nil from
// CGWindowListCopyWindowInfo — e.g. no window-server access in the calling
// context — or an empty list) exits 1 with a stderr line and MUST be treated
// as "oracle broken", never as "no windows exist". The 2026-07-29 incident
// (see docs/aerospace/RETILE-DELAY.md) happened because a force-cast crash here made an
// empty list look like universal window death. No layer filter on purpose:
// consumers only test membership, and a superset can't create a false ghost.
// Compiled on demand by its consumers (see reap-ghosts.sh header).
import CoreGraphics
import Foundation

guard let wl = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]],
      !wl.isEmpty else {
    FileHandle.standardError.write(Data("cg-window-ids: window server gave nil/empty list — oracle unusable in this context\n".utf8))
    exit(1)
}
for w in wl {
    if let num = w["kCGWindowNumber"] as? Int {
        print(num)
    }
}
