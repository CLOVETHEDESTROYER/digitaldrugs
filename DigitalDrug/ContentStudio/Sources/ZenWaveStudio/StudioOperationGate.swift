import Foundation
import Darwin

/// Shared file locks cover a complete render/batch, including receipts and ZIP.
/// The exclusive update lock drains existing work and prevents a new process
/// from rendering during installation. Locks vanish automatically on process exit.
final class StudioOperationLease: @unchecked Sendable {
    private var descriptor: Int32
    private let lock = NSLock()
    init(_ descriptor: Int32) { self.descriptor = descriptor }
    func release() {
        lock.lock(); defer { lock.unlock() }
        if descriptor >= 0 { flock(descriptor, LOCK_UN); close(descriptor); descriptor = -1 }
    }
    deinit { release() }
}

final class StudioOperationGate: @unchecked Sendable {
    static let shared = StudioOperationGate(url: ContentHistory.directory.appendingPathComponent("studio-operation.lock"))
    let url: URL
    private let lock = NSLock()
    private var pending = false
    init(url: URL) { self.url = url }
    var updatePending: Bool { lock.lock(); defer { lock.unlock() }; return pending }
    private func acquire(_ mode: Int32) throws -> StudioOperationLease? {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let descriptor = open(url.path, O_CREAT | O_RDWR | O_CLOEXEC, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else { throw StudioError.message("Could not coordinate rendering and updates.") }
        if flock(descriptor, mode | LOCK_NB) == 0 { return StudioOperationLease(descriptor) }
        let reason = errno; close(descriptor)
        if reason == EWOULDBLOCK || reason == EAGAIN { return nil }
        throw StudioError.message("Could not lock the studio for this operation.")
    }
    func tryWork() throws -> StudioOperationLease? {
        lock.lock(); defer { lock.unlock() }
        guard !pending else { return nil }
        return try acquire(LOCK_SH)
    }
    func beginWork() throws -> StudioOperationLease {
        guard let lease = try tryWork() else { throw StudioError.message("An app update is waiting or installing. Try the export again after it finishes.") }
        return lease
    }
    func waitForUpdate() async throws -> StudioOperationLease {
        markPending()
        do {
            while true {
                try Task.checkCancellation()
                if let lease = try acquire(LOCK_EX) { return lease }
                try await Task.sleep(nanoseconds: 100_000_000)
            }
        } catch { cancelUpdate(); throw error }
    }
    private func markPending() { lock.lock(); pending = true; lock.unlock() }
    func cancelUpdate() { lock.lock(); pending = false; lock.unlock() }
    /// Used by the detached installer after the GUI process exits.
    func tryExclusive() throws -> StudioOperationLease? { try acquire(LOCK_EX) }
}
