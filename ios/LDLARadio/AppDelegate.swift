//
//  AppDelegate.swift
//  LDLARadio
//
//  Created by Javier Fuchs on 1/6/17.
//  Copyright © 2017 Mobile Patagonia. All rights reserved.
//

import UIKit
import JFCore
import SwiftSpinner

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    var userDefault: UserDefaults?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        UserDefaults.standard.setValue(["en"], forKey: "AppleLanguages")
        RestApi.instance.context = CoreDataManager.instance.taskContext

        registerSettingsBundle()
        
        UIApplication.shared.beginReceivingRemoteControlEvents()
        
        SwiftSpinner.setTitleFont(UIFont.init(name: Commons.font.name, size: Commons.font.size))
        
        changeAppearance()

        return true
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
//        CoreDataManager.instance.save()
    }
    
    private func registerSettingsBundle() {
        var appDefaults = [String:AnyObject]()
        appDefaults["server_url"] = RestApi.Constants.Service.ldlaServer as AnyObject?
        UserDefaults.standard.register(defaults: appDefaults)
        
        NotificationCenter.default.addObserver(self, selector: #selector(AppDelegate.defaultsChanged), name: UserDefaults.didChangeNotification, object: nil)
    }
    
    private func changeAppearance() {
        let attributes = [NSAttributedString.Key.font: UIFont(name: Commons.font.name, size: 15)!,
                          NSAttributedString.Key.foregroundColor: UIColor.gray]
        UINavigationBar.appearance().titleTextAttributes = attributes

        let headerLabel = UILabel.appearance(whenContainedInInstancesOf: [UITableViewHeaderFooterView.self])
        headerLabel.font = UIFont(name: Commons.font.name, size: 14)!
        headerLabel.textColor = .lightGray
        headerLabel.shadowColor = .black
        headerLabel.shadowOffset = CGSize(width: -1, height: -1)
    }
    
    @objc func defaultsChanged() {
        userDefault = UserDefaults.standard
    }
    
}
