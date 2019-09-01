//
//  Audio+.swift
//  LDLARadio
//
//  Created by fox on 19/08/2019.
//  Copyright © 2019 Mobile Patagonia. All rights reserved.
//

import Foundation
import CoreData
import CloudKit
import AVKit
import JFCore

extension Audio: Modellable {

    static func all() -> [Audio]? {
        return all(predicate: nil, sortDescriptors: nil) as? [Audio]
    }

}

extension Audio: Searchable {

    /// Fetch an object by url
    static func search(byUrl url: String?) -> Audio? {
        guard let url = url else { return nil }
        guard let context = RestApi.instance.context else { fatalError() }
        let req = NSFetchRequest<Audio>(entityName: "Audio")
        req.predicate = NSPredicate(format: "urlString = %@", url)
        let object = try? context.fetch(req).first
        return object
    }

    /// Fetch an object by id
    static func search(byIdentifier id: String?) -> Audio? {
        guard let context = RestApi.instance.context else { fatalError() }
        guard let id = id else { return nil }
        let req = NSFetchRequest<Audio>(entityName: "Audio")
        req.predicate = NSPredicate(format: "id = %@", id)
        let array = try? context.fetch(req)
        return array?.first
    }

    /// Returns the streams for a given name.
    static func search(byName name: String?) -> [Audio]? {
        guard let context = RestApi.instance.context else { fatalError() }
        guard let name = name else { return nil }
        let req = NSFetchRequest<Audio>(entityName: "Audio")
        req.predicate = NSPredicate(format: "title = %@ OR title CONTAINS[cd] %@ OR subTitle = %@ OR subTitle CONTAINS[cd] %@ OR detail = %@ OR detail CONTAINS[cd] %@", name, name, name, name, name, name)
        let array = try? context.fetch(req)
        return array
    }

}

extension Audio {
    /// Create Audio entity programatically
    static func create() -> Audio? {
        guard let context = RestApi.instance.context else { fatalError() }
        guard let entity = NSEntityDescription.entity(forEntityName: "Audio", in: context) else {
            fatalError()
        }
        let audio = NSManagedObject(entity: entity, insertInto: context) as? Audio
        return audio
    }

    static func create(record: CKRecord) -> Audio? {

        var audio: Audio? = Audio.search(byUrl: record["url"])

        if audio == nil {
            audio = Audio.create()
        }

        if audio == nil {
            return nil
        }

        audio?.detail = record["detail"] as? String
        audio?.id = record["id"] as? String
        audio?.placeholder = record["placeholder"] as? String
        audio?.subTitle = record["subTitle"] as? String
        audio?.thumbnailUrl = record["thumbnailUrl"] as? String
        audio?.title = record["title"] as? String
        audio?.urlString = record["url"] as? String
        audio?.section = record["section"] as? String
        audio?.recordID = record.recordID.recordName
        audio?.descript = record["descript"] as? String
        audio?.currentTime = record["currentTime"] as? Double ?? 0.0
        audio?.hasDuration = record["hasDuration"] as? Bool ?? false

        return audio
    }

}

extension Audio {
    /// Using += as a overloading assignment operator for AudioViewModel's in Audio entities
    static func +=(audio: inout Audio, audioViewModel: AudioViewModel) {
        audio.detail = audioViewModel.detail.text
        audio.id = audioViewModel.id
        audio.placeholder = audioViewModel.placeholderImageName
        audio.subTitle = audioViewModel.subTitle.text
        audio.thumbnailUrl = audioViewModel.thumbnailUrl?.absoluteString
        audio.title = audioViewModel.title.text
        audio.urlString = audioViewModel.url?.absoluteString
        audio.section = audioViewModel.section
        audio.descript = audioViewModel.text
    }

    /// Using += as a overloading assignment operator for CatalogViewModel's in Bookmark entities
    static func +=(audio: inout Audio, catalogViewModel: CatalogViewModel) {
        audio.detail = catalogViewModel.detail.text
        audio.subTitle = catalogViewModel.title.text
        audio.title = catalogViewModel.tree
        audio.urlString = catalogViewModel.urlString()
        audio.section = catalogViewModel.section
        audio.descript = catalogViewModel.text
    }

    /// Use the url of the stream/audio as an AVURLAsset
    func urlAsset() -> AVURLAsset? {
        guard let urlString = urlString,
            let url = URL(string: urlString) else { return nil }
        return AVURLAsset(url: url)
    }

    func info() -> (String, String, String?, String?) {
        var array = [String]()
        for str in [title, subTitle, section, detail] {
            if let str = str, str.count > 0 {
                array.append(str)
            }
        }
        return (array.joined(separator: ".\n"), descript ?? "", errorTitle, errorMessage)
    }
    
    /// Fetch an objects not sync with cloud kit
    static func unsyncs() -> [Audio]? {
        guard let context = RestApi.instance.context else { fatalError() }
        let req = NSFetchRequest<Audio>(entityName: "Audio")
        req.predicate = NSPredicate(format: "cloudSynced == false")
        let array = try? context.fetch(req)
        return array
    }

    static func changeCatalogBookmark(model: CatalogViewModel?) {
        guard let model = model else {
            fatalError()
        }
        for audio in model.audios {
            changeAudioBookmark(model: audio, useRefresh: false)
        }
    }
    
    static func changeAudioBookmark(model: AudioViewModel?, useRefresh: Bool = true) {
        
        guard let context = RestApi.instance.context else { fatalError() }
        guard let model = model else { fatalError() }
        BaseController.isBookmarkChanged = true
        
        context.performAndWait {
            var audio: Audio?
            if let audiotmp = Audio.search(byUrl: model.url?.absoluteString) {
                audio = audiotmp
            } else if let audiotmp = Audio.create() {
                audio = audiotmp
                audio? += model
            } else {
                fatalError()
            }
            audio?.changeBookmark(useRefresh: useRefresh)
            model.isBookmarked = audio?.isBookmark

            if useRefresh {
                CoreDataManager.instance.save()
            }
        }
    }

    func changeBookmark(useRefresh: Bool = true) {
        
        BaseController.isBookmarkChanged = true
        
        isBookmark = !isBookmark
        Analytics.logFunction(function: "bookmark",
                              parameters: ["action": isBookmark as AnyObject,
                                           "title": title as AnyObject,
                                           "section": section as AnyObject,
                                           "url": urlString as AnyObject])
    }
}
