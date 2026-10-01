import CoreGraphics
import Foundation

enum EventTapLifecycle: Equatable, Sendable {
    case stopped
    case starting
    case running
    case failed(String)
}

struct EventTapSnapshot: Equatable, Sendable {
    let lifecycle: EventTapLifecycle
    let tapEnabled: Bool
    let recoveryCount: Int
}

final class EventTapController: @unchecked Sendable {
    private let lock = NSLock()
    private var lifecycle: EventTapLifecycle = .stopped
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var eventRunLoop: CFRunLoop?
    private var workerThread: Thread?
    private var policyState = TouchGuardPolicy.State()
    private var protectionEnabled = true
    private var intervalNanoseconds: UInt64 = 200_000_000
    private var recoveryCount = 0

    func start() {
        lock.lock()
        guard workerThread == nil else {
            lock.unlock()
            return
        }

        lifecycle = .starting
        let thread = Thread { [weak self] in
            self?.runEventLoop()
        }
        thread.name = "TouchGuard.EventTap"
        workerThread = thread
        lock.unlock()
        thread.start()
    }

    func stop() {
        lock.lock()
        let runLoop = eventRunLoop
        lock.unlock()

        guard let runLoop else {
            return
        }

        CFRunLoopPerformBlock(runLoop, CFRunLoopMode.commonModes.rawValue) {
            CFRunLoopStop(runLoop)
        }
        CFRunLoopWakeUp(runLoop)
    }

    func setProtectionEnabled(_ enabled: Bool) {
        lock.lock()
        protectionEnabled = enabled
        if !enabled {
            policyState = TouchGuardPolicy.State()
        }
        lock.unlock()
    }

    func setInterval(seconds: Double) {
        lock.lock()
        intervalNanoseconds = UInt64(seconds * 1_000_000_000)
        lock.unlock()
    }

    func snapshot() -> EventTapSnapshot {
        lock.lock()
        let currentLifecycle = lifecycle
        let currentTap = eventTap
        let currentRecoveryCount = recoveryCount
        lock.unlock()

        let enabled = currentTap.map { CGEvent.tapIsEnabled(tap: $0) } ?? false
        return EventTapSnapshot(
            lifecycle: currentLifecycle,
            tapEnabled: enabled,
            recoveryCount: currentRecoveryCount
        )
    }

    private func runEventLoop() {
        autoreleasepool {
            let mask = Self.eventMask
            guard let tap = CGEvent.tapCreate(
                tap: .cgSessionEventTap,
                place: .headInsertEventTap,
                options: .defaultTap,
                eventsOfInterest: mask,
                callback: eventTapCallback,
                userInfo: Unmanaged.passUnretained(self).toOpaque()
            ) else {
                finish(with: .failed("Unable to create event tap"))
                return
            }

            let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
            let runLoop = CFRunLoopGetCurrent()

            lock.lock()
            eventTap = tap
            runLoopSource = source
            eventRunLoop = runLoop
            lock.unlock()

            CFRunLoopAddSource(runLoop, source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)

            guard CGEvent.tapIsEnabled(tap: tap) else {
                CFMachPortInvalidate(tap)
                finish(with: .failed("macOS refused to enable the event tap"))
                return
            }

            lock.lock()
            lifecycle = .running
            lock.unlock()

            CFRunLoopRun()
            CFRunLoopRemoveSource(runLoop, source, .commonModes)
            CFMachPortInvalidate(tap)

            lock.lock()
            let finalLifecycle: EventTapLifecycle
            if case .failed = lifecycle {
                finalLifecycle = lifecycle
            } else {
                finalLifecycle = .stopped
            }
            lock.unlock()
            finish(with: finalLifecycle)
        }
    }

    private func finish(with finalLifecycle: EventTapLifecycle) {
        lock.lock()
        lifecycle = finalLifecycle
        eventTap = nil
        runLoopSource = nil
        eventRunLoop = nil
        workerThread = nil
        policyState = TouchGuardPolicy.State()
        lock.unlock()
    }

    fileprivate func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            recoverEventTap()
            return Unmanaged.passUnretained(event)
        }

        let inputEvent: TouchGuardPolicy.InputEvent
        switch type {
        case .keyDown:
            inputEvent = .keyDown
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            inputEvent = .mouseDown(button: event.getIntegerValueField(.mouseEventButtonNumber))
        case .leftMouseUp, .rightMouseUp, .otherMouseUp:
            inputEvent = .mouseUp(button: event.getIntegerValueField(.mouseEventButtonNumber))
        default:
            inputEvent = .other
        }

        lock.lock()
        let decision = TouchGuardPolicy.evaluate(
            event: inputEvent,
            nowNanoseconds: DispatchTime.now().uptimeNanoseconds,
            intervalNanoseconds: intervalNanoseconds,
            enabled: protectionEnabled,
            state: &policyState
        )
        lock.unlock()

        return decision == .suppress ? nil : Unmanaged.passUnretained(event)
    }

    private func recoverEventTap() {
        lock.lock()
        let tap = eventTap
        recoveryCount += 1
        lock.unlock()

        guard let tap else {
            return
        }

        CGEvent.tapEnable(tap: tap, enable: true)
        guard !CGEvent.tapIsEnabled(tap: tap) else {
            return
        }

        lock.lock()
        lifecycle = .failed("macOS disabled the event tap and it could not be restored")
        let runLoop = eventRunLoop
        lock.unlock()

        guard let runLoop else {
            return
        }
        CFRunLoopStop(runLoop)
        CFRunLoopWakeUp(runLoop)
    }

    private static let eventMask: CGEventMask = [
        CGEventType.keyDown,
        .leftMouseDown,
        .leftMouseUp,
        .rightMouseDown,
        .rightMouseUp,
        .otherMouseDown,
        .otherMouseUp,
    ].reduce(0) { mask, type in
        mask | (CGEventMask(1) << type.rawValue)
    }
}

private let eventTapCallback: CGEventTapCallBack = { _, type, event, userInfo in
    guard let userInfo else {
        return Unmanaged.passUnretained(event)
    }

    let controller = Unmanaged<EventTapController>.fromOpaque(userInfo).takeUnretainedValue()
    return controller.handle(type: type, event: event)
}
