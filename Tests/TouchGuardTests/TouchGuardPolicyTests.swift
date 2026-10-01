import Testing
@testable import TouchGuard

struct TouchGuardPolicyTests {
    @Test
    func keyDownStartsSuppressionWindow() {
        var state = TouchGuardPolicy.State()

        let keyDecision = TouchGuardPolicy.evaluate(
            event: .keyDown,
            nowNanoseconds: 1_000,
            intervalNanoseconds: 200,
            enabled: true,
            state: &state
        )
        let clickDecision = TouchGuardPolicy.evaluate(
            event: .mouseDown(button: 0),
            nowNanoseconds: 1_199,
            intervalNanoseconds: 200,
            enabled: true,
            state: &state
        )

        #expect(keyDecision == .pass)
        #expect(clickDecision == .suppress)
    }

    @Test
    func clickAtBoundaryPasses() {
        var state = TouchGuardPolicy.State()
        _ = TouchGuardPolicy.evaluate(
            event: .keyDown,
            nowNanoseconds: 1_000,
            intervalNanoseconds: 200,
            enabled: true,
            state: &state
        )

        let decision = TouchGuardPolicy.evaluate(
            event: .mouseDown(button: 0),
            nowNanoseconds: 1_200,
            intervalNanoseconds: 200,
            enabled: true,
            state: &state
        )

        #expect(decision == .pass)
    }

    @Test
    func suppressedMouseDownAlsoSuppressesMatchingMouseUp() {
        var state = TouchGuardPolicy.State()
        _ = TouchGuardPolicy.evaluate(
            event: .keyDown,
            nowNanoseconds: 1_000,
            intervalNanoseconds: 200,
            enabled: true,
            state: &state
        )
        _ = TouchGuardPolicy.evaluate(
            event: .mouseDown(button: 0),
            nowNanoseconds: 1_100,
            intervalNanoseconds: 200,
            enabled: true,
            state: &state
        )

        let decision = TouchGuardPolicy.evaluate(
            event: .mouseUp(button: 0),
            nowNanoseconds: 1_300,
            intervalNanoseconds: 200,
            enabled: true,
            state: &state
        )

        #expect(decision == .suppress)
        #expect(state.suppressedButtons.isEmpty)
    }

    @Test
    func disablingProtectionClearsPendingSuppression() {
        var state = TouchGuardPolicy.State()
        _ = TouchGuardPolicy.evaluate(
            event: .keyDown,
            nowNanoseconds: 1_000,
            intervalNanoseconds: 200,
            enabled: true,
            state: &state
        )

        let disabledDecision = TouchGuardPolicy.evaluate(
            event: .mouseDown(button: 0),
            nowNanoseconds: 1_100,
            intervalNanoseconds: 200,
            enabled: false,
            state: &state
        )
        let laterDecision = TouchGuardPolicy.evaluate(
            event: .mouseDown(button: 0),
            nowNanoseconds: 1_101,
            intervalNanoseconds: 200,
            enabled: true,
            state: &state
        )

        #expect(disabledDecision == .pass)
        #expect(laterDecision == .pass)
        #expect(state == TouchGuardPolicy.State())
    }

    @Test
    func repeatedKeyDownExtendsSuppressionWindow() {
        var state = TouchGuardPolicy.State()
        _ = TouchGuardPolicy.evaluate(
            event: .keyDown,
            nowNanoseconds: 1_000,
            intervalNanoseconds: 200,
            enabled: true,
            state: &state
        )
        _ = TouchGuardPolicy.evaluate(
            event: .keyDown,
            nowNanoseconds: 1_150,
            intervalNanoseconds: 200,
            enabled: true,
            state: &state
        )

        let decision = TouchGuardPolicy.evaluate(
            event: .mouseDown(button: 0),
            nowNanoseconds: 1_349,
            intervalNanoseconds: 200,
            enabled: true,
            state: &state
        )

        #expect(decision == .suppress)
    }
}
