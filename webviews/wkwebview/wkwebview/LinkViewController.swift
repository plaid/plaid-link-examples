//
//  LinkViewController.swift
//  wkwebview
//
//  Copyright (c) 2020 Plaid Inc. All rights reserved.
//

import UIKit
import WebKit

final class LinkViewController: UIViewController, WKNavigationDelegate {

    /// `handleRedirctURL` checks the `url` to see if it matches the redirect url used when creating a link token.
    /// If so, it re-initializes the webview to finish the link session. Returns `true` if handled, `false` otherwise.
    func handleRedirectURL(_ url: URL) -> Bool {
        /// This should be the same `redirect_uri` used when creating a link token via https://plaid.com/docs/api/tokens/#linktokencreate
        let redirectURI = URL(string: "<#YOUR_APPLICATION_REDIRECT_URI#>")!

        // Remove any trailing suffixes to normalize comparison.
        let urlPath = url.path.hasSuffix("/") ? String(url.path.dropLast()) : url.path
        let redirectURIPath = redirectURI.path.hasSuffix("/") ? String(redirectURI.path.dropLast()) : redirectURI.path

        // If the loaded url matches the redirectURI, then re-initialize the webview to complete the
        // authentication flow with the additional `receivedRedirectUri` parameter.
        if redirectURI.host == url.host && redirectURIPath == urlPath && redirectURI.scheme == url.scheme {
            let initialURL = generateLinkInitializationURL()
            if let newURL = initialURL.updating(value: url.absoluteString, for: "receivedRedirectUri") {
                webView.load(URLRequest(url: newURL))
                return true
            }
        }
        return false
    }

    // MARK: UIViewController

    override func viewDidLoad() {
        super.viewDidLoad()

        webView.navigationDelegate = self
        webView.allowsBackForwardNavigationGestures = false
        webView.frame = view.frame
        webView.scrollView.bounces = false
        self.view.addSubview(webView)

        // load the link url
        let url = generateLinkInitializationURL()
        webView.load(URLRequest(url: url))
    }

    override var prefersStatusBarHidden : Bool {
        return true
    }

    // MARK: WKNavigationDelegate

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping ((WKNavigationActionPolicy) -> Void)
    ) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }

        let linkScheme = "plaidlink";
        let actionScheme = url.scheme;
        let actionType = url.host ?? "";
        let queryParams = getUrlParams(url: url)

        if actionScheme == linkScheme {
            switch actionType {
            case "connected":
                // Close the webview
                _ = self.navigationController?.popViewController(animated: true)

                // Parse data passed from Link into a dictionary
                // This includes the public_token as well as account and institution metadata
                print(
                    """
                    Public Token: \(queryParams["public_token"] ?? "")
                    Account ID: \(queryParams["account_id"] ?? "")
                    Institution type: \(queryParams["institution_type"] ?? "")
                    Institution name: \(queryParams["institution_name"] ?? "")
                    """
                )
                break

            case "exit":
                // Close the webview
                _ = self.navigationController?.popViewController(animated: true)

                // Parse data passed from Link into a dictionary
                // This includes information about where the user was in the Link flow
                // any errors that occurred, and request IDs
                print("URL: \(url.absoluteString)")
                // Output data from Link
                print("User status in flow: \(queryParams["status"] ?? "")");
                // The requet ID keys may or may not exist depending on when the user exited
                // the Link flow.
                print("Link request ID: \(queryParams["link_request_id"] ?? "")");
                print("Plaid API request ID: \(queryParams["link_request_id"] ?? "")");
                break

            case "event":
                 // The event action is fired as the user moves through the Link flow
                print("Event name: \(queryParams["event_name"] ?? "")");
                break
            default:
                print("Link action detected: \(actionType)")
                break
            }

            decisionHandler(.cancel)
            return
        }

        // Check if the url is our known redirect url. Universal links are not triggered when the WKWebView is running
        // in the universal link's target application. Manually handle this case now.
        if handleRedirectURL(url) {
            decisionHandler(.cancel)
            return
        }

        if navigationAction.navigationType == WKNavigationType.linkActivated &&
            (actionScheme == "http" || actionScheme == "https") {
            // Handle http:// and https:// links inside of Plaid Link,
            // and open them in a new Safari page. This is necessary for links
            // such as "forgot-password" and "locked-account"
            UIApplication.shared.open(navigationAction.request.url!, options: convertToUIApplicationOpenExternalURLOptionsKeyDictionary([:]), completionHandler: nil)
            decisionHandler(.cancel)
            return
        }

        // Allow anything not explicitly handled above.
        decisionHandler(.allow)
    }

    // MARK: Private

    private let webView = WKWebView()

    /// generateLinkInitializationURL :: create the link.html url with query parameters
    func generateLinkInitializationURL() -> URL {
        // Create a new link_token via the /link/token/create endpoint. You will be
        // able to configure this link_token to control Link behavior. To learn more
        // about how to create a link_token, visit https://plaid.com/docs/#create-link-token.
        //
        // After creating a link_token, replace <#GENERATED_LINK_TOKEN#> with it below.
        let config = [
            "token": "<#GENERATED_LINK_TOKEN#>",
            "isMobile": "true",
            "isWebview": "true",
        ]

        // Build a dictionary with the Link configuration options
        // See the Link docs (https://plaid.com/docs/quickstart) for full documentation.
        var components = URLComponents()
        components.scheme = "https"
        components.host = "cdn.plaid.com"
        components.path = "/link/v2/stable/link.html"
        components.queryItems = config.map { URLQueryItem(name: $0, value: $1) }
        return components.url!
    }

    /// getUrlParams - parse query parameters into a Dictionary
    private func getUrlParams(url: URL) -> [String: String] {
        guard let queryItems = URLComponents(string: (url.absoluteString))?.queryItems else {
            return [:]
        }
        return Dictionary(
            uniqueKeysWithValues: zip(
                queryItems.map { return $0.name },
                queryItems.map { return $0.value ?? "" }
            )
        )
    }
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertToUIApplicationOpenExternalURLOptionsKeyDictionary(_ input: [String: Any]) -> [UIApplication.OpenExternalURLOptionsKey: Any] {
	return Dictionary(uniqueKeysWithValues: input.map { key, value in (UIApplication.OpenExternalURLOptionsKey(rawValue: key), value)})
}

extension URL {
    func updating(value: String, for queryParameter: String) -> URL? {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else {
            return nil
        }

        let replacementItem = URLQueryItem(name: queryParameter, value: value)
        if let index = components.queryItems?.firstIndex(where: { $0.name == replacementItem.name }) {
            components.queryItems?.remove(at: index)
        }
        components.queryItems?.append(replacementItem)

        return components.url
    }
}
