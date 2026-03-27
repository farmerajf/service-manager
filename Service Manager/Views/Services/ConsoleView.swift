import SwiftUI

struct ConsoleView: View {
    let logBuffer: LogBuffer
    @State private var autoScroll = true

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 1) {
                    ForEach(logBuffer.entries) { entry in
                        HStack(spacing: 6) {
                            Text(entry.timestamp, format: .dateTime.hour().minute().second().secondFraction(.fractional(3)))
                                .foregroundStyle(.secondary)
                                .font(.system(.caption, design: .monospaced))
                            Text(entry.text)
                                .foregroundStyle(entry.stream == .stderr ? .red : .primary)
                        }
                        .font(.system(.body, design: .monospaced))
                        .id(entry.id)
                    }
                }
                .textSelection(.enabled)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(.black.opacity(0.8))
            .onChange(of: logBuffer.count) {
                if autoScroll, let last = logBuffer.entries.last {
                    withAnimation {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
        .overlay(alignment: .bottomTrailing) {
            Toggle("Auto-scroll", isOn: $autoScroll)
                .toggleStyle(.switch)
                .controlSize(.small)
                .padding(6)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
                .padding(8)
        }
    }
}
