//
//  AppDelegate.swift
//  point2
//
//  Created by Mikey Lintz on 10/21/17.
//  Copyright © 2017 Mikey Lintz. All rights reserved.
//

import UIKit
import SwiftyDropbox

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

  var window: UIWindow?


  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
    // Override point for customization after application launch.
    DropboxClientsManager.setupWithAppKey("vhw99dne2ubfcs6")
    return true
  }

  func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey : Any] = [:]) -> Bool {
    if let authResult = DropboxClientsManager.handleRedirectURL(url) {
      switch authResult {
      case .success:
        print("Success! User is logged into Dropbox.")
      case .cancel:
        fatalError("Authorization flow was manually canceled by user!")
      case .error(_, let description):
        fatalError("Error: \(description)")
      }
    }
    return true
  }
}

