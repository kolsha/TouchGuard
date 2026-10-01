import Foundation

enum TouchGuardPolicy {
    struct State: Equatable, Sendable {
        var suppressUntilNanoseconds: UInt64 = 0
        var suppressedButtons: Set<Int64> = []
    }

    enum InputEvent: Equatable, Sendable {
        case keyDown
        case mouseDown(button: Int64)
        case mouseUp(button: Int64)
        case other
    }

    enum Decision: Equatable, Sendable {
        case pass
        case suppress
    }

    static func evaluate(
        event: InputEvent,
        nowNanoseconds: UInt64,
        intervalNanoseconds: UInt64,
        enabled: Bool,
        state: inout State
    ) -> Decision {
        guard enabled else {
            state = State()
            return .pass
        }

        switch event {
        case .keyDown:
            state.suppressUntilNanoseconds = nowNanoseconds + intervalNanoseconds
            return .pass

        case let .mouseDown(button):
            guard nowNanoseconds < state.suppressUntilNanoseconds else {
                return .pass
            }
            state.suppressedButtons.insert(button)
            return .suppress

        case let .mouseUp(button):
            guard state.suppressedButtons.remove(button) != nil else {
                return .pass
            }
            return .suppress

        case .other:
            return .pass
        }
    }
}
