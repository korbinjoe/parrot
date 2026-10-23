import Foundation
import Combine

/// Keeps each service's test result attached to the configuration that was tested.
@MainActor
final class CredentialOperationState: ObservableObject {
    @Published private(set) var notes: [String: SettingsView.CredentialNote] = [:]

    private var tasks: [String: Task<Void, Never>] = [:]
    private var generations: [String: UUID] = [:]

    deinit {
        for task in tasks.values {
            task.cancel()
        }
    }

    @discardableResult
    func run(
        serviceID: String,
        operation: @escaping @MainActor () async -> SettingsView.CredentialNote
    ) -> Task<Void, Never> {
        invalidate(serviceID: serviceID)
        let generation = UUID()
        generations[serviceID] = generation
        notes[serviceID] = .validating

        let task = Task { @MainActor [weak self] in
            guard !Task.isCancelled else { return }
            let note = await operation()
            guard !Task.isCancelled,
                  let self,
                  self.generations[serviceID] == generation else { return }
            self.tasks[serviceID] = nil
            self.notes[serviceID] = note
        }
        tasks[serviceID] = task
        return task
    }

    /// Editing a draft makes any previous or in-flight test result obsolete.
    func invalidate(serviceID: String) {
        tasks.removeValue(forKey: serviceID)?.cancel()
        generations[serviceID] = UUID()
        notes[serviceID] = nil
    }

    func cancel(serviceID: String) {
        set(.saved(L("已取消测试")), for: serviceID)
    }

    /// Saving or removing credentials supersedes an earlier test operation.
    func set(_ note: SettingsView.CredentialNote, for serviceID: String) {
        invalidate(serviceID: serviceID)
        notes[serviceID] = note
    }

    func cancelAll() {
        for task in tasks.values {
            task.cancel()
        }
        tasks.removeAll()
        generations.removeAll()
        notes.removeAll()
    }

    func isRunning(serviceID: String) -> Bool {
        tasks[serviceID] != nil
    }
}
