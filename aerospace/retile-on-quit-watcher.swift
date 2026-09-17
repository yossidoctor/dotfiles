import Cocoa

NSWorkspace.shared.notificationCenter.addObserver(
    forName: NSWorkspace.didTerminateApplicationNotification,
    object: nil,
    queue: .main
) { _ in
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/aerospace")
    task.arguments = ["list-windows", "--all"]
    task.standardOutput = FileHandle.nullDevice
    task.standardError = FileHandle.nullDevice
    try? task.run()

    let bar = Process()
    bar.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/sketchybar")
    bar.arguments = ["--trigger", "aerospace_window_change"]
    bar.standardOutput = FileHandle.nullDevice
    bar.standardError = FileHandle.nullDevice
    try? bar.run()
}

RunLoop.main.run()
