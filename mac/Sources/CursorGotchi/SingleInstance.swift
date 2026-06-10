import Foundation
import Darwin

enum SingleInstance {
    static let showPanelNotification = Notification.Name("com.cursor.token-gotchi.show-panel")

    private static var lockFileURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".cursor/token-gotchi/app.lock")
    }

    private static var lockFD: Int32 = -1

    /// Returns true if this process should run; false if another instance is active.
    static func acquire() -> Bool {
        let dir = lockFileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let fd = open(lockFileURL.path, O_CREAT | O_RDWR, 0o644)
        guard fd >= 0 else { return true }

        if flock(fd, LOCK_EX | LOCK_NB) != 0 {
            close(fd)
            notifyExistingInstance()
            return false
        }

        lockFD = fd
        ftruncate(fd, 0)
        let pid = "\(ProcessInfo.processInfo.processIdentifier)\n"
        _ = pid.withCString { write(fd, $0, strlen($0)) }
        return true
    }

    static func release() {
        guard lockFD >= 0 else { return }
        flock(lockFD, LOCK_UN)
        close(lockFD)
        lockFD = -1
        try? FileManager.default.removeItem(at: lockFileURL)
    }

    private static func notifyExistingInstance() {
        DistributedNotificationCenter.default().post(name: showPanelNotification, object: nil)
    }
}
