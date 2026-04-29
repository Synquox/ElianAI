import SwiftUI
import WebKit
import MarkdownUI

/// Renders LaTeX equations using KaTeX in a WKWebView
/// Supports both inline ($...$) and block ($$...$$) LaTeX
struct LaTeXView: UIViewRepresentable {
    let latex: String
    let fontSize: CGFloat
    
    @Binding var dynamicHeight: CGFloat
    
    init(_ latex: String, fontSize: CGFloat = 18, dynamicHeight: Binding<CGFloat> = .constant(60)) {
        self.latex = latex
        self.fontSize = fontSize
        self._dynamicHeight = dynamicHeight
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let controller = WKUserContentController()
        controller.add(context.coordinator, name: "heightHandler")
        
        let config = WKWebViewConfiguration()
        config.userContentController = controller
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.navigationDelegate = context.coordinator
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        let html = generateHTML()
        webView.loadHTMLString(html, baseURL: nil)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    /// Escapes HTML entities to prevent injection
    private func sanitize(_ input: String) -> String {
        input
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
    
    private func generateHTML() -> String {
        let safeLatex = sanitize(latex)
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0">
            <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/katex@0.16.11/dist/katex.min.css">
            <script src="https://cdn.jsdelivr.net/npm/katex@0.16.11/dist/katex.min.js"></script>
            <script src="https://cdn.jsdelivr.net/npm/katex@0.16.11/dist/contrib/auto-render.min.js"></script>
            <style>
                * { margin: 0; padding: 0; box-sizing: border-box; }
                body {
                    background: transparent;
                    color: #F0F0F5;
                    font-family: -apple-system, BlinkMacSystemFont, sans-serif;
                    font-size: \(fontSize)px;
                    padding: 8px 4px;
                    line-height: 1.6;
                }
                .katex-display {
                    margin: 8px 0;
                    overflow-x: auto;
                }
                .katex { font-size: 1.1em; color: #F0F0F5; }
                /* Fallback for offline: show raw text legibly */
                .katex-error { color: #9090A8; font-family: monospace; font-size: 0.9em; }
            </style>
        </head>
        <body>
            <div id="content">\(safeLatex)</div>
            <script>
                document.addEventListener("DOMContentLoaded", function() {
                    if (typeof renderMathInElement === 'function') {
                        renderMathInElement(document.getElementById("content"), {
                            delimiters: [
                                {left: "$$", right: "$$", display: true},
                                {left: "$", right: "$", display: false},
                                {left: "\\\\(", right: "\\\\)", display: false},
                                {left: "\\\\[", right: "\\\\]", display: true}
                            ],
                            throwOnError: false
                        });
                    }
                    // Report height back
                    setTimeout(function() {
                        window.webkit.messageHandlers.heightHandler.postMessage(
                            document.body.scrollHeight
                        );
                    }, 200);
                });
            </script>
        </body>
        </html>
        """
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: LaTeXView
        
        init(_ parent: LaTeXView) {
            self.parent = parent
        }
        
        // Handle height messages from JS
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "heightHandler", let height = message.body as? CGFloat {
                DispatchQueue.main.async {
                    self.parent.dynamicHeight = height
                }
            }
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.evaluateJavaScript("document.body.scrollHeight") { [weak self] result, _ in
                if let height = result as? CGFloat {
                    DispatchQueue.main.async {
                        self?.parent.dynamicHeight = height
                    }
                }
            }
        }
    }
}

/// A text view that detects and renders LaTeX inline with regular text
struct RichTextView: View {
    let text: String
    
    var body: some View {
        let segments = parseSegments(text)
        
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                switch segment {
                case .text(let content):
                    Markdown(content)
                        .markdownTheme(.elianAI)
                        .textSelection(.enabled)
                case .latex(let equation):
                    LaTeXView(equation)
                        .frame(height: 50)
                case .blockLatex(let equation):
                    LaTeXView("$$\(equation)$$", fontSize: 20)
                        .frame(height: 70)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }
    
    enum Segment {
        case text(String)
        case latex(String)
        case blockLatex(String)
    }
    
    private func parseSegments(_ input: String) -> [Segment] {
        var segments: [Segment] = []
        var remaining = input
        
        while !remaining.isEmpty {
            // Check for block LaTeX ($$...$$)
            if let blockRange = remaining.range(of: "\\$\\$(.+?)\\$\\$", options: .regularExpression) {
                let before = String(remaining[remaining.startIndex..<blockRange.lowerBound])
                if !before.isEmpty {
                    segments.append(.text(before))
                }
                let match = String(remaining[blockRange])
                let equation = match.dropFirst(2).dropLast(2)
                segments.append(.blockLatex(String(equation)))
                remaining = String(remaining[blockRange.upperBound...])
            }
            // Check for inline LaTeX ($...$)
            else if let inlineRange = remaining.range(of: "\\$(.+?)\\$", options: .regularExpression) {
                let before = String(remaining[remaining.startIndex..<inlineRange.lowerBound])
                if !before.isEmpty {
                    segments.append(.text(before))
                }
                let match = String(remaining[inlineRange])
                let equation = match.dropFirst(1).dropLast(1)
                segments.append(.latex(String(equation)))
                remaining = String(remaining[inlineRange.upperBound...])
            }
            else {
                segments.append(.text(remaining))
                remaining = ""
            }
        }
        
        return segments
    }
}
