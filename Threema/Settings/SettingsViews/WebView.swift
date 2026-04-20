import SwiftUI
import WebKit
 
struct WebView: View {
    let url: URL
    let title: String
    
    var body: some View {
        WebViewRepresentable(url: url)
            .navigationBarTitle(title, displayMode: .inline)
    }
}

private struct WebViewRepresentable: UIViewRepresentable {
    var url: URL
 
    func makeUIView(context: Context) -> WKWebView {
        WKWebView()
    }
 
    func updateUIView(_ webView: WKWebView, context: Context) {
        let request = URLRequest(url: url)
        webView.load(request)
    }
}
