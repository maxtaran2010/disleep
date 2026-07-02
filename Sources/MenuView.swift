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

            if model.sleepDisabled {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.orange)
                    Text("Your Mac will not sleep — even with the lid closed. Watch battery and heat.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
            }

            Divider()

            HStack(spacing: 6) {
                Circle()
                    .fill(model.authorized ? Color.green : Color.red)
                    .frame(width: 7, height: 7)
                Text(model.authorized ? "Authorized" : "Not authorized")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
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
