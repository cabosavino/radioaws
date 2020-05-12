//
//  Searchable.swift
//  LDLARadio
//
//  Created by fox on 27/07/2019.
//  Copyright © 2019 Mobile Patagonia. All rights reserved.
//

import Foundation

internal protocol Searchable: Modellable {

    /// Returns the entities for a given name.
    static func search(byName name: String?) -> [ModelType]?

    /// Fetch an object by url
    static func search(byUrl url: String?) -> ModelType?

    static var placeholderImageName: String { get }

}
