package com.example.linkwebview

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.util.Log
import android.view.View
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.Toast
import androidx.activity.ComponentActivity
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.launch
import androidx.activity.viewModels
import kotlinx.coroutines.withContext

class MainActivity : ComponentActivity() {

    companion object {
        private const val PLAID_LINK_BASE_URL = "https://cdn.plaid.com/link/v2/stable/link.html"
    }

    private val plaidLinkWebview by lazy { findViewById<View>(R.id.webview) as WebView }
    private val viewModel: MainActivityViewModel by viewModels<MainActivityViewModel>()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        initWebview()

        // If receiving a redirect (from OAuth), reload the same URL with that redirect.
        maybeHandleOAuthRedirect(intent)

        GlobalScope.launch(Dispatchers.Main) {
            val linkToken = generateLinkToken()
            if (linkToken == null) {
                Toast.makeText(this@MainActivity, "Please provide a valid Link token", Toast.LENGTH_LONG).show()
            } else {
                viewModel.linkInitializationUrl =
                    "$PLAID_LINK_BASE_URL?isWebview=true&isMobile=true&token=$linkToken"

                // Initialize Link by loading the Link initialization URL in the Webview
                viewModel.linkInitializationUrl?.let {
                    plaidLinkWebview.loadUrl(it)
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent?) {
        super.onNewIntent(intent)
        // Depending on your Activity's launch mode, it may receive the redirect here or in onCreate.
        maybeHandleOAuthRedirect(intent)
    }

    /**
     * You need to first create a link_token by calling /link/token/create from your backend.
     * This call should never happen directly from the mobile client, as it risks exposing your API secret.
     *
     * To test this sample, you can generate a token from the following curl:
     * curl -i -X POST --header 'Content-Type: application/json' -d'{"country_codes":["US"], "client_name": "<REPLACE>", "client_id":"<REPLACE>", "secret": "<REPLACE>>", "redirect_uri": "<REPLACE>", "language": "en", "products":["auth"], "user": {"client_user_id": "xxxx"}}' https://sandbox.plaid.com/link/token/create
     */
     private suspend fun generateLinkToken(): String? = withContext(Dispatchers.IO){
        // TODO return token here
        return@withContext null
    }

    /**
     * When logging into a financial institution, the customer may leave your app to log in
     * via an external browser or App2App using oAuth. After logging in, the user will get
     * redirected to your application.
     *
     * For this to work, a number of things need to be set up:
     * 1. Provide your domain as a redirect_uri while creating a Link token
     * 2. Add an intent filter to receive redirects to the Android manifest.
     *    In this example, replace `<data android:host="your.domain.com" />` with your domain
     * 3. Host a `.well-known/assetlinks.json` file on your domain as explained by
     *    https://developer.android.com/training/app-links/verify-android-applinks
     */
    private fun maybeHandleOAuthRedirect(intent: Intent?) {
        val receivedRedirectUri = intent?.data
        if (receivedRedirectUri != null) {
            Log.d("RedirectURI", receivedRedirectUri.toString())
            // Example url: "https://myapp.com?oauth_state_id=9d5feadd-a873-43eb-97ba-422f35ce849b
            val newUrl = Uri.parse(viewModel.linkInitializationUrl).buildUpon().appendQueryParameter("receivedRedirectUri", receivedRedirectUri.toString()).toString()
            plaidLinkWebview.loadUrl(newUrl)
            return
        }
    }

    /**
     * Setup webview configuration.
     */
    private fun initWebview() {
        // Modify Webview settings - all of these settings may not be applicable
        // or necessary for your integration.

        // These settings need to be added in order to run Plaid Link
        plaidLinkWebview.settings.apply {
            javaScriptEnabled = true
            domStorageEnabled = true
            cacheMode = WebSettings.LOAD_NO_CACHE
        }

        // Optional: This allows all traffic to be debugged, should be turned off in production.
        WebView.setWebContentsDebuggingEnabled(true)

        // Override the Webview's handler for redirects
        // Link communicates success and failure (analogous to the web's onSuccess and onExit
        // callbacks) via redirects.
        plaidLinkWebview.webViewClient = object : WebViewClient() {
            override fun shouldOverrideUrlLoading(view: WebView, url: String): Boolean {
                // Parse the URL to determine if it's a special Plaid Link redirect or a request
                // for a standard URL (typically a forgotten password or account not setup link).
                // Handle Plaid Link redirects and open traditional pages directly in the  user's
                // preferred browser.
                val parsedUri = Uri.parse(url)
                return if (parsedUri.scheme == "plaidlink") {
                    val action = parsedUri.host
                    val linkData = parseLinkUriData(parsedUri)
                    if (action == "connected") {
                        // User successfully linked
                        Log.d("Public token: ", linkData["public_token"]!!)
                        Log.d("Account ID: ", linkData["account_id"]!!)
                        Log.d("Account name: ", linkData["account_name"]!!)
                        Log.d("Institution id: ", linkData["institution_id"]!!)
                        Log.d(
                            "Institution name: ",
                            linkData["institution_name"]!!
                        )

                        // Reload Link in the Webview
                        // You will likely want to transition the view at this point.
                        Toast.makeText(this@MainActivity, "Success: ${linkData["public_token"]}", Toast.LENGTH_SHORT).show()
                        viewModel.linkInitializationUrl?.let {
                            plaidLinkWebview.loadUrl(it)
                        }
                    } else if (action == "exit") {
                        // User exited
                        // linkData may contain information about the user's status in the Link flow,
                        // the institution selected, information about any error encountered,
                        // and relevant API request IDs.
                        Log.d("User status in flow: ", linkData["status"]!!)
                        // The request ID keys may or may not exist depending on when the user exited
                        // the Link flow.
                        Log.d("Link request ID: ", linkData["link_request_id"]!!)
                        Log.d(
                            "API request ID: ",
                            linkData["plaid_api_request_id"]!!
                        )

                        // Reload Link in the Webview
                        // You will likely want to transition the view at this point.
                        Toast.makeText(this@MainActivity, "Exited session: ${linkData["link_session_id"]}", Toast.LENGTH_SHORT).show()
                        viewModel.linkInitializationUrl?.let {
                            plaidLinkWebview.loadUrl(it)
                        }
                    } else if (action == "event") {
                        // The event action is fired as the user moves through the Link flow
                        Log.d("Event name: ", linkData["event_name"]!!)
                    } else {
                        Log.d("Link action detected: ", action!!)
                    }
                    // Override URL loading
                    true
                } else if (parsedUri.scheme == "https" || parsedUri.scheme == "http") {
                    // Open in browser - this is most  typically for 'account locked' or
                    // 'forgotten password' redirects
                    view.context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
                    // Override URL loading
                    true
                } else {
                    // Unknown case - do not override URL loading
                    false
                }
            }
        }
    }

    // Parse a Link redirect URL querystring into a HashMap for easy manipulation and access
    fun parseLinkUriData(linkUri: Uri): HashMap<String, String?> {
        val linkData = HashMap<String, String?>()
        for (key in linkUri.queryParameterNames) {
            linkData[key] = linkUri.getQueryParameter(key)
        }
        return linkData
    }
}
