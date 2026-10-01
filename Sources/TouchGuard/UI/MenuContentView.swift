import SwiftUI

struct MenuContentView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            statusCard

            Toggle("Protection", isOn: $model.protectionEnabled)
                .toggleStyle(.switch)
                .disabled(!model.permissionGranted)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Ignore clicks for")
                    Spacer()
                    Text(model.intervalSeconds, format: .number.precision(.fractionLength(1)))
                        .monospacedDigit()
                    Text("s")
                        .foregroundStyle(.secondary)
                }
                Slider(value: $model.intervalSeconds, in: 0.1...1.0, step: 0.1)
                    .disabled(!model.protectionEnabled)
            }

            Divider()

            Toggle(
                "Launch at Login",
                isOn: Binding(
                    get: { model.launchAtLoginEnabled },
                    set: { model.setLaunchAtLogin($0) }
                )
            )
            .toggleStyle(.switch)

            if model.launchAtLoginNeedsApproval {
                Button("Approve in System Settings") {
                    model.openLoginItemsSettings()
                }
                .buttonStyle(.link)
            }

            if let error = model.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                if model.eventTapSnapshot.recoveryCount > 0 {
                    Text("Recovered \(model.eventTapSnapshot.recoveryCount)×")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Quit") {
                    model.quit()
                }
                .keyboardShortcut("q")
            }
        }
        .padding(16)
        .frame(width: 320)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "hand.raised.fill")
                .font(.title2)
            Text("TouchGuard")
                .font(.headline)
            Spacer()
        }
    }

    private var statusCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: model.protectionStatus.symbolName)
                .font(.title3)
                .foregroundStyle(statusColor)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 3) {
                Text(model.protectionStatus.title)
                    .font(.subheadline.weight(.semibold))
                Text(model.protectionStatus.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                switch model.protectionStatus {
                case .needsPermission:
                    Button("Grant Accessibility Access") {
                        model.requestAccessibilityAccess()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .padding(.top, 5)
                case .failed:
                    Button("Retry") {
                        model.retryEventTap()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .padding(.top, 5)
                default:
                    EmptyView()
                }
            }
        }
        .padding(12)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
    }

    private var statusColor: Color {
        switch model.protectionStatus {
        case .active: .green
        case .paused, .starting: .secondary
        case .needsPermission, .failed: .orange
        }
    }
}
