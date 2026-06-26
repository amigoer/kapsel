import SwiftUI

/// A scrollable terminal console view that displays monospace command line outputs
struct TerminalView: View {
    let content: String
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(content.isEmpty ? "No terminal output available" : content)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(content.isEmpty ? .secondary : .green)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .lineSpacing(4)
                            .textSelection(.enabled) // Enable select and copy
                            .padding()
                        
                        Color.clear
                            .frame(height: 1)
                            .id("bottom")
                    }
                }
                .background(Color.black)
                .cornerRadius(8)
                .onChange(of: content) { _, _ in
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
                .onAppear {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
            
            if !content.isEmpty {
                Button(action: {
                    let pasteboard = NSPasteboard.general
                    pasteboard.declareTypes([.string], owner: nil)
                    pasteboard.setString(content, forType: .string)
                }) {
                    Image(systemName: "doc.on.doc.fill")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(8)
                        .background(Color.white.opacity(0.15))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .padding(12)
                .help("Copy logs to clipboard")
            }
        }
    }
}
