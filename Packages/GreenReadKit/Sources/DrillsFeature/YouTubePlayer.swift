import SwiftUI
import WebKit

/// A privacy-enhanced YouTube embed that plays inline.
struct YouTubePlayer: UIViewRepresentable {
    let videoID: String

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.scrollView.isScrollEnabled = false
        view.isOpaque = false
        view.backgroundColor = .black
        return view
    }

    func updateUIView(_ view: WKWebView, context: Context) {
        guard context.coordinator.loadedID != videoID else { return }
        context.coordinator.loadedID = videoID
        let html = """
            <!doctype html><html><head>
            <meta name="viewport" content="width=device-width,initial-scale=1">
            <style>html,body{margin:0;height:100%;background:#000}iframe{border:0;width:100%;height:100%}</style>
            </head><body>
            <iframe src="https://www.youtube-nocookie.com/embed/\(videoID)?playsinline=1&rel=0&modestbranding=1"
              allow="autoplay; encrypted-media; picture-in-picture" allowfullscreen></iframe>
            </body></html>
            """
        view.loadHTMLString(html, baseURL: URL(string: "https://greenread.app"))
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var loadedID: String?
    }
}
