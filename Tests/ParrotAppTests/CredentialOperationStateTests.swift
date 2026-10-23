import Testing
@testable import ParrotApp

@MainActor
@Test func credentialTestKeepsCompletedResultUntilConfigurationChanges() async {
    let state = CredentialOperationState()
    let operation = CredentialOperationLatch()
    let task = state.run(serviceID: "service") { await operation.result() }

    #expect(state.notes["service"] == .validating)
    #expect(state.isRunning(serviceID: "service"))
    await operation.waitUntilStarted()
    operation.finish(.failed("Connection was refused."))
    await task.value

    #expect(state.notes["service"] == .failed("Connection was refused."))
    #expect(!state.isRunning(serviceID: "service"))
}

@MainActor
@Test func credentialNewerTestCannotBeOverwrittenByOldRequest() async {
    let state = CredentialOperationState()
    let oldOperation = CredentialOperationLatch()
    let newOperation = CredentialOperationLatch()
    let oldTask = state.run(serviceID: "service") { await oldOperation.result() }
    await oldOperation.waitUntilStarted()

    let newTask = state.run(serviceID: "service") { await newOperation.result() }
    await newOperation.waitUntilStarted()
    #expect(oldTask.isCancelled)
    newOperation.finish(.valid("Current configuration works."))
    await newTask.value
    oldOperation.finish(.failed("Obsolete connection failure."))
    await oldTask.value

    #expect(state.notes["service"] == .valid("Current configuration works."))
    #expect(!state.isRunning(serviceID: "service"))
}

@MainActor
@Test func credentialEditingInvalidatesPendingResultEvenWhenOperationIgnoresCancellation() async {
    let state = CredentialOperationState()
    let operation = CredentialOperationLatch()
    let task = state.run(serviceID: "service") { await operation.result() }
    await operation.waitUntilStarted()

    state.invalidate(serviceID: "service")
    #expect(task.isCancelled)
    #expect(state.notes["service"] == nil)
    #expect(!state.isRunning(serviceID: "service"))
    operation.finish(.valid("This belongs to the previous draft."))
    await task.value

    #expect(state.notes["service"] == nil)
}

@MainActor
@Test func credentialCancellationReachesOperationAndRetainsCancelledStatus() async {
    let state = CredentialOperationState()
    let operation = CredentialOperationLatch()
    var operationObservedCancellation = false
    let task = state.run(serviceID: "service") {
        let result = await operation.result()
        operationObservedCancellation = Task.isCancelled
        return result
    }
    await operation.waitUntilStarted()

    state.cancel(serviceID: "service")
    let cancelledNote = state.notes["service"]
    guard case .saved(let message) = cancelledNote else {
        Issue.record("Cancellation should leave a visible status.")
        operation.finish(.valid("Ignored result."))
        await task.value
        return
    }
    #expect(!message.isEmpty)
    #expect(task.isCancelled)
    operation.finish(.valid("Ignored result."))
    await task.value

    #expect(operationObservedCancellation)
    #expect(state.notes["service"] == cancelledNote)
    #expect(!state.isRunning(serviceID: "service"))
}

@MainActor
@Test func credentialCancellingBeforeTestStartsAvoidsRequest() async {
    let state = CredentialOperationState()
    var operationStarted = false
    let task = state.run(serviceID: "service") {
        operationStarted = true
        return .valid("Unexpected request.")
    }

    state.cancel(serviceID: "service")
    await task.value

    #expect(!operationStarted)
    #expect(!state.isRunning(serviceID: "service"))
}

@MainActor
@Test func credentialSavedOrRemovedStatusSupersedesPendingTest() async {
    let state = CredentialOperationState()
    let operation = CredentialOperationLatch()
    let task = state.run(serviceID: "service") { await operation.result() }
    await operation.waitUntilStarted()

    state.set(.saved("Saved key was removed."), for: "service")
    #expect(task.isCancelled)
    operation.finish(.valid("The removed key used to work."))
    await task.value

    #expect(state.notes["service"] == .saved("Saved key was removed."))
    #expect(!state.isRunning(serviceID: "service"))
}

@MainActor
@Test func credentialTestsForDifferentServicesRemainIndependent() async {
    let state = CredentialOperationState()
    let firstOperation = CredentialOperationLatch()
    let secondOperation = CredentialOperationLatch()
    let firstTask = state.run(serviceID: "first") { await firstOperation.result() }
    let secondTask = state.run(serviceID: "second") { await secondOperation.result() }
    await firstOperation.waitUntilStarted()
    await secondOperation.waitUntilStarted()

    state.invalidate(serviceID: "first")
    #expect(firstTask.isCancelled)
    #expect(!secondTask.isCancelled)
    #expect(state.isRunning(serviceID: "second"))
    firstOperation.finish(.failed("Old first-service result."))
    secondOperation.finish(.valid("Second service works."))
    await firstTask.value
    await secondTask.value

    #expect(state.notes["first"] == nil)
    #expect(state.notes["second"] == .valid("Second service works."))
}

@MainActor
@Test func credentialCancelAllRejectsAllLateResults() async {
    let state = CredentialOperationState()
    let firstOperation = CredentialOperationLatch()
    let secondOperation = CredentialOperationLatch()
    let firstTask = state.run(serviceID: "first") { await firstOperation.result() }
    let secondTask = state.run(serviceID: "second") { await secondOperation.result() }
    await firstOperation.waitUntilStarted()
    await secondOperation.waitUntilStarted()
    state.set(.valid("Previous test passed."), for: "completed")

    state.cancelAll()
    #expect(firstTask.isCancelled)
    #expect(secondTask.isCancelled)
    #expect(state.notes.isEmpty)
    #expect(!state.isRunning(serviceID: "first"))
    #expect(!state.isRunning(serviceID: "second"))
    firstOperation.finish(.valid("Old first result."))
    secondOperation.finish(.failed("Old second result."))
    await firstTask.value
    await secondTask.value

    #expect(state.notes.isEmpty)
}

@MainActor
@Test func credentialPendingOperationDoesNotRetainState() async {
    var state: CredentialOperationState? = CredentialOperationState()
    weak var weakState = state
    let operation = CredentialOperationLatch()
    let task = state!.run(serviceID: "service") { await operation.result() }
    await operation.waitUntilStarted()

    state = nil
    #expect(weakState == nil)
    #expect(task.isCancelled)
    operation.finish(.valid("Result after state disposal."))
    await task.value
}

/// Deliberately ignores cancellation so tests can release obsolete responses in any order.
@MainActor
private final class CredentialOperationLatch {
    private var resultContinuation: CheckedContinuation<SettingsView.CredentialNote, Never>?
    private var startContinuations: [CheckedContinuation<Void, Never>] = []
    private var started = false

    func result() async -> SettingsView.CredentialNote {
        await withCheckedContinuation { continuation in
            resultContinuation = continuation
            started = true
            let waiting = startContinuations
            startContinuations.removeAll()
            waiting.forEach { $0.resume() }
        }
    }

    func waitUntilStarted() async {
        if started { return }
        await withCheckedContinuation { continuation in
            startContinuations.append(continuation)
        }
    }

    func finish(_ note: SettingsView.CredentialNote) {
        precondition(resultContinuation != nil, "Wait for the operation to start before finishing it.")
        let continuation = resultContinuation
        resultContinuation = nil
        continuation?.resume(returning: note)
    }
}
