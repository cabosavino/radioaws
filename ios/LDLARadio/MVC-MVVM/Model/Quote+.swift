//
//  Quote+.swift
//  LDLARadio
//
//  Created by fox on 12/07/2019.
//  Copyright © 2019 Apple Inc. All rights reserved.
//

import Foundation
import JFCore
import Groot

extension Quote {
    
    private static func fromJsonFile(name: String) -> [[String: Any]]? {
        // Parse and insert media
        if let path = Bundle.main.path(forResource: name, ofType: "json") {
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: path), options: .mappedIfSafe)
                let jsonResponse = try JSONSerialization.jsonObject(with: data, options: [])
                return jsonResponse as? [[String: Any]]
            } catch {
                print("error = \(error)")
            }
        }
        return nil
    }
    
    
    private static func create() {
        do {
            guard let array = fromJsonFile(name: "quotes2"),
                let context = CoreDataManager.instance.taskContext else {
                return
            }
            for obj in array {
                _ = try object(withEntityName: "Quote", fromJSONDictionary: obj, inContext: context)
            }
            try context.save()
        }
        catch {
            print("error = \(error)")
        }
    }
    
    
    private static func queryRandomly() -> Quote? {
        guard let context = CoreDataManager.instance.taskContext else { fatalError() }
        let req = NSFetchRequest<Quote>(entityName: "Quote")
        let array = try? context.fetch(req)
        let n = array?.count ?? 0
        if n == 0 {
            return nil
        }
        let rnd = Int(arc4random())%n
        return array?[rnd]
    }

    private static func random() -> Quote? {
        if let quote = queryRandomly() {
            return quote
        }
        create()
        return queryRandomly()
    }
    
    static func randomQuote() -> String {
        guard let quote = random(),
            let text = quote.text else {
            return "If you spend your whole life waiting for the storm, you'll never enjoy the sunshine.\n~Morris West"
        }
        return "\(text)\n~\(quote.author ?? "")"
    }
}
