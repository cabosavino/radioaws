//
//  AppDelegate.swift
//  LDLARadio
//
//  Created by Javier Fuchs on 1/6/17.
//  Copyright © 2017 Mobile Patagonia. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    var userDefault: UserDefaults?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey : Any]? = nil) -> Bool {
        
        registerSettingsBundle()
        
        UIApplication.shared.beginReceivingRemoteControlEvents()
        
        // Restore the state of the application and any running downloads.
        StreamPersistenceManager.sharedManager.restorePersistenceManager()

        return true
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        
    }
    
    func registerSettingsBundle() {
        var appDefaults = [String:AnyObject]()
        appDefaults["server_url"] = "http://ec2-34-214-84-98.us-west-2.compute.amazonaws.com:3000" as AnyObject?
        UserDefaults.standard.register(defaults: appDefaults)
        
        NotificationCenter.default.addObserver(self, selector: #selector(AppDelegate.defaultsChanged), name: UserDefaults.didChangeNotification, object: nil)
    }
    
    @objc func defaultsChanged() {
        userDefault = UserDefaults.standard
    }
    
}
