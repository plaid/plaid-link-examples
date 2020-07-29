# Plaid Link - WKWebView

A simple example of Link inside of an WkWebView.

## How to run the example

First, you'll need a Plaid `client_id` and `secret`. Head on over
to [our documentation][quickstart] if you don't have them already.
You will need to use these values to create a new
[link_token][link-token-create].

Inside `LinkViewController.swift`, look for `<#GENERATED_LINK_TOKEN#>` and replace it
with the one you created.

Run the project. By default it is set up to run inside our `sandbox`
environment, meaning that instead of connecting actual bank accounts you can use
a set of [fake credentials][sandbox-docs] in order to test different types of
behavior.

[quickstart]: https://plaid.com/docs/quickstart/
[sandbox-docs]: https://plaid.com/docs/api/#sandbox
[link-token-create]: https://plaid.com/docs/#create-link-token
