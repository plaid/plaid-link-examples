//
//  AppDelegate.swift
//  wkwebview
//
//  Copyright (c) 2016 Plaid Inc. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        return true
    }

    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey : Any] = [:]
    ) -> Bool {
        // Your application will have a better way of tracking your view controllers. This is just for
        // demonstration purposes.
        guard let navigationController = window?.rootViewController as? UINavigationController else {
            return false
        }
        guard let linkViewController = navigationController.viewControllers.last as? LinkViewController else {
            return false
        }

        // Handle any incoming redirect URLs coming from financial institution apps.
        //
        // If your application is using UIWindowSceneDelegate you'll handle this in
        // `func scene(_ scene: UIScene, continue userActivity: NSUserActivity)` instead.
        return linkViewController.handleRedirectURL(url)
    }
}

