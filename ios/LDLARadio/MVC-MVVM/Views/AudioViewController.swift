//
//  AudioViewController.swift
//  LDLARadio
//
//  Created by fox on 22/07/2019.
//  Copyright © 2019 Mobile Patagonia. All rights reserved.
//

import UIKit
import AVFoundation
import AVKit
import MediaPlayer
import SwiftSpinner
import JFCore

class AudioViewController: UITableViewController {
    // MARK: Properties

    var isFullScreen: Bool = false

    @IBOutlet weak var refreshButton: UIBarButtonItem!

    var radioController = RadioController()
    var radioTimeController = RadioTimeController()
    var rnaController = RNAController()
    var bookmarkController = BookmarkController()
    var desconciertoController = ElDesconciertoController()
    var searchController = SearchController()
    var archiveOrgController = ArchiveOrgController()
    var archiveOrgMainModelController = ArchiveOrgMainModelController()

    var controller: BaseController {
        get {
            let title = titleForController()
            switch title {
                case AudioViewModel.ControllerName.suggestion.rawValue:
                    return radioController
                case AudioViewModel.ControllerName.radioTime.rawValue:
                    return radioTimeController
                case AudioViewModel.ControllerName.rna.rawValue:
                    return rnaController
                case AudioViewModel.ControllerName.bookmark.rawValue:
                    return bookmarkController
                case AudioViewModel.ControllerName.desconcierto.rawValue:
                    return desconciertoController
                case AudioViewModel.ControllerName.archiveOrg.rawValue:
                    return archiveOrgController
                case AudioViewModel.ControllerName.archiveMainModelOrg.rawValue:
                    return archiveOrgMainModelController
                case AudioViewModel.ControllerName.search.rawValue:
                    return searchController
                default:
                    fatalError()
                }
        }
        set {
            let title = titleForController()

            switch title {
            case AudioViewModel.ControllerName.suggestion.rawValue:
                radioController = newValue as! RadioController
                break
            case AudioViewModel.ControllerName.radioTime.rawValue:
                radioTimeController = newValue as! RadioTimeController
                break
            case AudioViewModel.ControllerName.rna.rawValue:
                rnaController = newValue as! RNAController
                break
            case AudioViewModel.ControllerName.bookmark.rawValue:
                bookmarkController = newValue as! BookmarkController
                break
            case AudioViewModel.ControllerName.desconcierto.rawValue:
                desconciertoController = newValue as! ElDesconciertoController
                break
            case AudioViewModel.ControllerName.archiveOrg.rawValue:
                archiveOrgController = newValue as! ArchiveOrgController
                break
            case AudioViewModel.ControllerName.archiveMainModelOrg.rawValue:
                archiveOrgMainModelController = newValue as! ArchiveOrgMainModelController
                break
            case AudioViewModel.ControllerName.search.rawValue:
                searchController = newValue as! SearchController
                break
            default:
                fatalError()
            }
        }
    }

    // MARK: UIViewController

    override func viewDidLoad() {
        super.viewDidLoad()

        SwiftSpinner.useContainerView(view)

        refreshButton.isEnabled = controller.useRefresh

        if controller.useRefresh {
            addRefreshControl()
        }
        tableView.remembersLastFocusedIndexPath = true
        HeaderTableView.setup(tableView: tableView)

        if (controller is SearchController) {
            refresh(isClean: true)
        }

        tableView.contentInset = UIEdgeInsets(top: 10, left: 0, bottom: 0, right: 0)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if controller is BookmarkController {
            navigationItem.leftBarButtonItems = [UIBarButtonItem(barButtonSystemItem: .trash, target: self, action: #selector(AudioViewController.trashAction(_:)))]
        }
        else {
            navigationItem.leftBarButtonItems = nil
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !(controller is SearchController) {
            refresh()
        } else {
            reloadData()
        }
        navigationController?.setToolbarHidden(false, animated: true)
    }

    private func titleForController() -> String? {
        let titleName = self.tabBarItem.title ?? self.navigationController?.tabBarItem.title ??  self.tabBarController?.selectedViewController?.tabBarItem.title
        return titleName
    }

    /// Refresh control to allow pull to refresh
    private func addRefreshControl() {
        let refreshControl = UIRefreshControl()
        refreshControl.accessibilityHint = "refresh"
        refreshControl.accessibilityLabel = "refresh"
        refreshControl.addTarget(self, action:
            #selector(AudioViewController.handleRefresh(_:)),
                                 for: .valueChanged)
        refreshControl.tintColor = UIColor.red

        tableView.addSubview(refreshControl)

    }

    func refresh(isClean: Bool = false, refreshControl: UIRefreshControl? = nil) {

        controller.refresh(isClean: isClean, prompt: "",
                           startClosure: {
                            SwiftSpinner.show(Quote.randomQuote())
        }) { (error) in
            if let error = error {
                self.showAlert(error: error)
                Analytics.logError(error: error)
            }
            refreshControl?.endRefreshing()
            SwiftSpinner.hide()
            self.reloadData()
        }
    }

    private func reloadData() {
        if !Thread.isMainThread {
            print("ojo")
        }
        tableView.refreshControl?.attributedTitle = controller.title().bigRed()
        navigationItem.prompt = controller.prompt()
        navigationItem.title = controller.title()
        tableView.reloadData()
        if let navigationBar = self.navigationController?.navigationBar,
            let tabBar = self.navigationController?.tabBarController?.tabBar ??
            self.tabBarController?.tabBar {

            navigationBar.isHidden = isFullScreen
            tabBar.isHidden = isFullScreen
            navigationController?.setNavigationBarHidden(isFullScreen, animated: true)
            tableView.allowsSelection = !isFullScreen
            tableView.isScrollEnabled = !isFullScreen
        }

        reloadToolbar()
    }

    private func reloadToolbar() {
        let stream = StreamPlaybackManager.instance
        let isPlaying = stream.isPlaying()
        let info = UIBarButtonItem(title: "\(Commons.symbols.showAwesome(icon: .info_circle))", style: .done, target: self, action: #selector(AudioViewController.info(_:)))
        info.setTitleTextAttributes([NSAttributedString.Key.font: UIFont(name: Commons.font.awesome, size: Commons.font.size.XXL)!], for: .normal)
        
        let size = CGSize(width: 40, height: 40)
        let image = stream.image()
        let imageView = UIImageView.init(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.frame = CGRect(origin: .zero, size: image?.size ?? size)
        imageView.heightAnchor.constraint(equalToConstant: size.height).isActive = true
        imageView.widthAnchor.constraint(equalToConstant: size.width).isActive = true

        navigationController?.toolbar.items = [
            UIBarButtonItem(customView: imageView),
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            UIBarButtonItem(barButtonSystemItem: .rewind, target: self, action: #selector(AudioViewController.handleRewind(_:))),
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            UIBarButtonItem(barButtonSystemItem: isPlaying ? .pause : .play, target: self, action: #selector(AudioViewController.handlePlay(_:))),
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            UIBarButtonItem(barButtonSystemItem: .fastForward, target: self, action: #selector(AudioViewController.handleFastForward(_:))),
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            info,
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        ]
        navigationController?.toolbar.setNeedsLayout()
    }

    @objc private func handleRewind(_ button: UIBarButtonItem) {
        StreamPlaybackManager.instance.backward()
        reloadData()
    }

    @objc private func handleFastForward(_ button: UIBarButtonItem) {
        StreamPlaybackManager.instance.forward()
        reloadData()
    }

    @objc private func handlePlay(_ button: UIBarButtonItem) {
        let stream = StreamPlaybackManager.instance
        let isPlaying = stream.isPlaying()
        if isPlaying {
            stream.pause()
        } else {
            stream.playCurrentPosition()
        }
        reloadData()
    }

    private func bookmark(indexPath: IndexPath, isReload: Bool = true) {
        let object = self.controller.model(forSection: indexPath.section, row: indexPath.row)
        if let audio = object as? AudioViewModel {
            controller.changeAudioBookmark(model: audio)
//            audio.isBookmarked = !(audio.isBookmarked ?? false)
//            tableView.reloadRows(at: [indexPath], with: .fade)
        }
        if let section = object as? CatalogViewModel {
            self.controller.changeCatalogBookmark(model: section)
        }
    }
    
    @objc private func info(_ sender: Any?) {
        let audioPlayInfo = StreamPlaybackManager.instance.info()
        showAlert(title: audioPlayInfo?.0, message: audioPlayInfo?.1, error: nil)
    }

    private func info(model: CatalogViewModel?) {
        showAlert(title: model?.title.text, message: model?.text, error: nil)
    }

    private func info(indexPath: IndexPath) {
        let object = controller.model(forSection: indexPath.section, row: indexPath.row)
        if let audio = object as? AudioViewModel {
            showAlert(title: audio.title.text, message: audio.info, error: nil)
        } else if let section = object as? CatalogViewModel {
            info(model: section)
        }
    }

    private func play(indexPath: IndexPath, isReload: Bool = true) {
        let object = controller.model(forSection: indexPath.section, row: indexPath.row)
        if let audio = object as? AudioViewModel {
            UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseIn, animations: {
                DispatchQueue.main.async {
                    let cell = self.tableView.cellForRow(at: indexPath) as? AudioTableViewCell
                    let stream = StreamPlaybackManager.instance
                    stream.delegate = cell
                    self.controller.play(forSection: indexPath.section, row: indexPath.row)
                    self.reloadToolbar()
                    if audio.isPlaying {
                        self.reloadData()
                    }
                }
            }) { (finished) in
                if finished {
                    if audio.isPlaying {
                        self.showCellAtTop(at: indexPath)
                    }
                }
            }
        } else if let section = object as? CatalogViewModel {
            if controller is RadioTimeController {
                performSegue(withIdentifier: Commons.segue.catalog, sender: section)
            } else if controller is ArchiveOrgController {
                performSegue(withIdentifier: Commons.segue.archiveorg, sender: section)
            } else if controller is SearchController {
                if section.section == AudioViewModel.ControllerName.radioTime.rawValue {
                    performSegue(withIdentifier: Commons.segue.catalog, sender: section)
                } else if section.section == AudioViewModel.ControllerName.archiveOrg.rawValue {
                    performSegue(withIdentifier: Commons.segue.archiveorg, sender: section)
                }
            }
        } else {
            if controller is ArchiveOrgController || controller is SearchController {
                if let cell = tableView.cellForRow(at: indexPath) as? LoadTableViewCell {
                    cell.start()
                }
                let model = controller.modelInstance(inSection: indexPath.section)
                expand(model: model, incrementPage: true, section: indexPath.section)
            }
        }

    }

    private func showCellAtTop(at indexPath: IndexPath) {
        if isFullScreen {
            guard let cell = self.tableView.cellForRow(at: indexPath) else {
                self.tableView.scrollToRow(at: indexPath, at: .top, animated: false)
                return
            }
            var point = cell.frame.origin
            point.y += self.tableView.frame.origin.y
            self.tableView.setContentOffset(point, animated: false)
        } else {
            self.tableView.scrollToRow(at: indexPath, at: .top, animated: false)
        }
    }

    private func expand(model: CatalogViewModel?, incrementPage: Bool = false, section: Int) {
        // Reusing the same model, but focus in this section
        controller.expand(model: model, section: section,
                          incrementPage: incrementPage,
                          startClosure: {
            RestApi.instance.context?.performAndWait {
                SwiftSpinner.show(Quote.randomQuote())
            }
        }, finishClosure: { (error) in
            if let error = error {
                self.showAlert(error: error)
                Analytics.logError(error: error)
            }
            SwiftSpinner.hide()
            self.reloadData()
        })
    }

    /// Handler of the pull to refresh, it clears the info container, reload the view and made another request using RestApi
    @objc func handleRefresh(_ refreshControl: UIRefreshControl) {
        Analytics.logFunction(function: "refresh",
                              parameters: ["method": "control" as AnyObject,
                                           "controller": titleForController() as AnyObject])

        refresh(isClean: true, refreshControl: refreshControl)
    }

    @IBAction func trashAction(_ sender: Any) {
        let alert = UIAlertController(title: "Bookmark Reset", message: "Do you want to clean your bookmarks?", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        let clean = UIAlertAction.init(title: "Clean", style: .destructive) { _ in
            DispatchQueue.main.async {
                SwiftSpinner.show(Quote.randomQuote())
            }

            Bookmark.clean()
            CloudKitManager.instance.clean(finishClosure: { (error) in
                if error != nil {
                    self.showAlert(title: "Error", message: "Trying to clean", error: error)
                    DispatchQueue.main.async {
                        SwiftSpinner.hide()
                    }
                }
                else {
                    self.refresh(isClean: true)
                }
            })
        }
        alert.addAction(clean)
        self.present(alert, animated: true, completion: nil)
    }
    
    @IBAction func shareAction(_ sender: Any) {
        share(indexPath: nil, controller: controller, tableView: tableView)
    }

    @IBAction func refreshAction(_ sender: Any) {
        refresh(isClean: true)
    }

    @IBAction func searchAction(_ sender: Any) {

        let alert = UIAlertController(title: "Search", message: "What do you need to search?", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        alert.addTextField { (textfield) in
            textfield.placeholder = "Search"
            textfield.text = (self.controller as? SearchController)?.textToSearch
            textfield.autocorrectionType = .no
            textfield.autocapitalizationType = .none
        }
        let search = UIAlertAction.init(title: "Search", style: .default) { _ in
            guard let textToSearch = alert.textFields?[0],
                let text = textToSearch.text,
                text.count > 0 else {
                return
            }
            if self.controller is SearchController {
                (self.controller as? SearchController)?.textToSearch = text
                self.refresh(isClean: true)
            } else {
                self.performSegue(withIdentifier: Commons.segue.search, sender: text)
            }
        }
        alert.addAction(search)
        self.present(alert, animated: true, completion: nil)
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return controller.numberOfSections()
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return controller.numberOfRows(inSection: section)
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let headerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: HeaderTableView.reuseIdentifier) as? HeaderTableView
        headerView?.model = controller.modelInstance(inSection: section)
        headerView?.actionExpandBlock = { model, isHighlighted in
            self.expand(model: model, section: section)
        }
        headerView?.actionBookmarkBlock = { model, isHighlighted in
            self.controller.changeCatalogBookmark(model: model)
        }
        headerView?.infoBlock = { model in
            self.info(model: model)
        }
        return headerView
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return controller.heightForRow(at: indexPath.section, row: indexPath.row)
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if isFullScreen {
            return 0
        }
        let model = controller.modelInstance(inSection: section)
        let h = controller.heightForHeader(at: section)
        if model?.isExpanded ?? false {
            return h * 1.5
        } else {
            return h
        }
    }

    override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        let object = controller.model(forSection: indexPath.section, row: indexPath.row)
        if object is AudioViewModel {
            return indexPath
        }
        if let section = object as? CatalogViewModel {
            if section.selectionStyle == .none {
                return nil
            }
        }
        return indexPath
    }

    override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {

        var actions = [UITableViewRowAction]()

        let object = controller.model(forSection: indexPath.section, row: indexPath.row)
        var isBookmarked: Bool? = false
        if let audio = object as? AudioViewModel {
            let stream = StreamPlaybackManager.instance
            let isPlaying = stream.isPlaying(url: audio.urlString())
            let playAction = UITableViewRowAction(style: .normal, title: isPlaying ? "Pause" : "Play") { (_, indexPath) in
                self.play(indexPath: indexPath)
            }
            playAction.backgroundColor = .cayenne
            actions.append(playAction)

            isBookmarked = audio.isBookmarked
        }

        if let section = object as? CatalogViewModel {
            isBookmarked = section.isBookmarked
        }
        if let isBookmarked = isBookmarked {
            let bookmarkAction = UITableViewRowAction(style: .destructive, title: isBookmarked ? "Delete" : "Add") { (_, indexPath) in
                self.bookmark(indexPath: indexPath)
            }
            bookmarkAction.backgroundColor = isBookmarked ? .lavender : .blueberry
            actions.append(bookmarkAction)
        }

        let shareAction = UITableViewRowAction(style: .normal, title: "Share") { (_, indexPath) in
            self.share(indexPath: indexPath, controller: self.controller, tableView: self.tableView)
        }
        shareAction.backgroundColor = .orchid
        actions.append(shareAction)

        return actions

    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let object = controller.model(forSection: indexPath.section, row: indexPath.row)
        if let audio = object as? AudioViewModel {
            guard let cell = tableView.dequeueReusableCell(withIdentifier: AudioTableViewCell.reuseIdentifier, for: indexPath) as? AudioTableViewCell else { fatalError() }
            cell.delegate = self
            cell.model = audio
            return cell
        }
        if let section = object as? CatalogViewModel {
            guard let cell = tableView.dequeueReusableCell(withIdentifier: CatalogTableViewCell.reuseIdentifier, for: indexPath) as? CatalogTableViewCell else { fatalError() }
            cell.model = section
            cell.actionBookmarkBlock = { catalog, isBookmarking in
                self.controller.changeCatalogBookmark(at: indexPath.section, row: indexPath.row)
            }
            cell.infoBlock = { catalog in
                self.info(model: catalog)
            }
            return cell
        }
        guard let cell = tableView.dequeueReusableCell(withIdentifier: LoadTableViewCell.reuseIdentifier, for: indexPath) as? LoadTableViewCell else { fatalError() }
        if controller is BookmarkController {
            cell.titleView?.text = "You should tap on the Apple button to get some."
        } else if controller is SearchController {
            cell.titleView?.text = "Please try again with another search term."
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        play(indexPath: indexPath)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == Commons.segue.catalog {
            segue.destination.tabBarItem.title = AudioViewModel.ControllerName.radioTime.rawValue
            (segue.destination as? AudioViewController)?.controller = RadioTimeController(withCatalogViewModel: (sender as? CatalogViewModel))
        } else if segue.identifier == Commons.segue.archiveorg {
            segue.destination.tabBarItem.title = AudioViewModel.ControllerName.archiveMainModelOrg.rawValue
            (segue.destination as? AudioViewController)?.controller = ArchiveOrgMainModelController(withCatalogViewModel: (sender as? CatalogViewModel))
        } else if segue.identifier == Commons.segue.search {
            segue.destination.tabBarItem.title = AudioViewModel.ControllerName.search.rawValue
            (segue.destination as? AudioViewController)?.controller = SearchController(withText: (sender as? String))
        }
        SwiftSpinner.hide()
    }

}

/**
 Extend `AudioViewController` to conform to the `AudioTableViewCellDelegate` protocol.
 */
extension AudioViewController: AudioTableViewCellDelegate {

    func audioTableViewCell(_ cell: AudioTableViewCell, bookmarkDidChange newState: Bool) {
        guard let indexPath = tableView.indexPath(for: cell) else { return }
        bookmark(indexPath: indexPath)
    }

    func audioTableViewCell(_ cell: AudioTableViewCell, downloadStateDidChange newState: Stream.DownloadState) {
        guard let indexPath = tableView.indexPath(for: cell) else { return }
        tableView.reloadRows(at: [indexPath], with: .automatic)
    }

    func audioTableViewCell(_ cell: AudioTableViewCell, didPlay newState: Bool) {
        guard let indexPath = tableView.indexPath(for: cell) else { return }
        play(indexPath: indexPath)
    }

    func audioTableViewCell(_ cell: AudioTableViewCell, didResize newState: Bool) {
        guard let indexPath = tableView.indexPath(for: cell) else { return }
        let object = controller.model(forSection: indexPath.section, row: indexPath.row)
        if let audio = object as? AudioViewModel {
            Analytics.logFunction(function: "resize",
                                  parameters: ["audio": audio.title.text as AnyObject,
                                               "isPlaying": audio.isPlaying as AnyObject,
                                               "didResize": newState as AnyObject,
                                               "url": audio.urlString() as AnyObject,
                                               "controller": titleForController() as AnyObject])
            isFullScreen = audio.isFullScreen
            UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseIn, animations: {
                DispatchQueue.main.async {
                    self.reloadData()
                }
            }) { (finished) in
                if finished {
                    self.showCellAtTop(at: indexPath)
                }
            }

        }

    }

    func audioTableViewCell(_ cell: AudioTableViewCell, didChangeTargetSound newState: Bool) {

    }

    func audioTableViewCell(_ cell: AudioTableViewCell, didChangeToEnd toEnd: Bool) {
        StreamPlaybackManager.instance.seekEnd()
    }

    func audioTableViewCell(_ cell: AudioTableViewCell, didChangeOffset isBackward: Bool) {
        let stream = StreamPlaybackManager.instance
        if isBackward {
            stream.backward()
        } else {
            stream.forward()
        }
    }

    func audioTableViewCell(_ cell: AudioTableViewCell, didChangePosition newValue: Float) {
        StreamPlaybackManager.instance.playPosition(position: Double(newValue))
    }

    func audioTableViewCell(_ cell: AudioTableViewCell, didShowInfo newValue: Bool) {
        guard let indexPath = tableView.indexPath(for: cell) else { return }
        info(indexPath: indexPath)
    }

    func audioTableViewCell(_ cell: AudioTableViewCell, didShowBug newValue: Bool) {
        guard let indexPath = tableView.indexPath(for: cell) else { return }
        let object = controller.model(forSection: indexPath.section, row: indexPath.row)
        if let audio = object as? AudioViewModel {
            showAlert(title: audio.title.text, message: audio.text, error: audio.error)
        }
    }

    func audioTableViewCell(_ cell: AudioTableViewCell, didShowGraph newValue: Bool) {
        
    }

    func audioTableViewCell(_ cell: AudioTableViewCell, didUpdate newValue: Bool) {
        reloadData()
    }

}
