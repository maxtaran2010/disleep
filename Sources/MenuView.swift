import SwiftUI
import AppKit

struct MenuView: View {
    @ObservedObject var model: AppModel

    private var isOn: Binding<Bool> {
        Binding(
            get: { model.sleepDisabled },
            set: { _ in AppController.shared.toggle() }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(model.sleepDisabled ? Color.orange.opacity(0.18) : Color.primary.opacity(0.08))
                        .frame(width: 36, height: 36)
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(model.sleepDisabled ? Color.orange : Color(nsColor: .systemGray))
                        .scaleEffect(model.sleepDisabled ? 1.0 : 0.92)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Disleep")
                        .font(.system(size: 13, weight: .semibold))
                    Text(model.sleepDisabled ? "Sleep is disabled" : "Normal sleep")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("", isOn: isOn)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .tint(.orange)
                    .disabled(model.busy)
            }

            Divider()

            HStack(spacing: 6) {
                Button {
                    NotificationCenter.default.post(name: .disleepDismissPanel, object: nil)
                    SettingsWindowController.shared.show()
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Settings")
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .keyboardShortcut("q", modifiers: .command)
            }
        }
        .padding(14)
        .frame(width: 300)
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: model.sleepDisabled)
    }
}
