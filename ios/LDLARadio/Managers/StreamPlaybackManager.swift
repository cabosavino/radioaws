//
//  StreamPlaybackManager.swift
//  LDLARadio
//
//  Created by Javier Fuchs on 1/6/17.
//  Copyright © 2017 Mobile Patagonia. All rights reserved.
//

import UIKit
import AVKit
import AVFoundation
import MediaPlayer
import JFCore

class StreamPlaybackManager: NSObject {
    // MARK: Properties
    
    /// Singleton for StreamPlaybackManager.
    static let instance = StreamPlaybackManager()
    
    private var observerContext = 0
    
    weak var delegate: AssetPlaybackDelegate?
    
    private lazy var session : URLSession = {
        guard let bundleID = Bundle.main.bundleIdentifier else { fatalError() }
        
        let config = URLSessionConfiguration.background(withIdentifier: "\(bundleID).background")
        config.sessionSendsLaunchEvents = true
        config.isDiscretionary = false
        config.timeoutIntervalForRequest = 120
        
        let instanceSession = URLSession(configuration: config, delegate: self, delegateQueue: OperationQueue())

        // Warning: If an URLSession still exists from a previous download, it doesn't create
        // a new URLSession object but returns the existing one with the old delegate object attached!
        //            let instanceSession = URLSession(configuration: config, delegate: self, delegateQueue: OperationQueue())
        return instanceSession
    }()

    /// The instance of AVPlayer that will be used for playback of StreamPlaybackManager.playerItem.
    private let player = AVPlayer()
    private let playerVC = AVPlayerViewController()

    /// A Bool tracking if the AVPlayerItem.status has changed to .readyToPlay for the current StreamPlaybackManager.playerItem.
    private var readyForPlayback = false

    
    /// The AVPlayerItem associated with StreamPlaybackManager.asset.urlAsset
    private var playerItem: AVPlayerItem?
    {
        willSet {
            if ((playerItem?.observationInfo) != nil) {
                playerItem?.removeObserver(self, forKeyPath: #keyPath(AVPlayerItem.status), context: &observerContext)
            }
        }
        didSet {
            playerItem?.addObserver(self, forKeyPath: #keyPath(AVPlayerItem.status), options: [.initial, .new], context: &observerContext)
        }
    }
    
    /// The Stream that is currently being loaded for playback.
    private var audioPlay: AudioPlay? {
        willSet {
            audioPlay?.isPlaying = false
            let urlAsset = audioPlay?.urlAsset()
            urlAsset?.resourceLoader.setDelegate(nil, queue: .main)
            if ((urlAsset?.observationInfo) != nil) {
                urlAsset?.removeObserver(self, forKeyPath: #keyPath(AVURLAsset.isPlayable), context: &observerContext)
            }
        }
        
        didSet {
            audioPlay?.isPlaying = false
            if let urlAsset = audioPlay?.urlAsset() {
                urlAsset.resourceLoader.setDelegate(self, queue: .main)
                urlAsset.addObserver(self, forKeyPath: #keyPath(AVURLAsset.isPlayable), options: [.initial, .new], context: &observerContext)
            }
            else {
                playerItem = nil
                player.replaceCurrentItem(with: nil)
                readyForPlayback = false
            }
        }
    }
    
    // MARK: Initialization
    override private init() {
        super.init()
        
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers, .allowBluetooth, .allowAirPlay, .allowBluetoothA2DP, .defaultToSpeaker, .duckOthers])
            try audioSession.setActive(true)
        }
        catch let error as NSError {
            let error = JFError(code: Int(errno),
                                desc: "Error",
                                reason: "Audio Session failed",
                                suggestion: "Please check the audio in your device",
                                underError: error)
            audioPlay?.error = error.message()
            delegate?.streamPlaybackManager(self, playerError: error)
            return
        }
        
        if let sd = session.sessionDescription {
            print("sessionDescription = %@", sd)
        }
        restartObservers()
    }
    
    deinit {
        let nc = NotificationCenter.default
        nc.removeObserver(self)
        player.removeObserver(self, forKeyPath: #keyPath(AVPlayer.currentItem))
    }
    
    fileprivate func restartObservers() {
        let nc = NotificationCenter.default
        nc.removeObserver(self)
        
        let playerItemNotes = [.AVPlayerItemTimeJumped, .AVPlayerItemDidPlayToEndTime, .AVPlayerItemFailedToPlayToEndTime, .AVPlayerItemPlaybackStalled, .AVPlayerItemNewAccessLogEntry, .AVPlayerItemNewErrorLogEntry] as [NSNotification.Name]
        for note in playerItemNotes {
            nc.addObserver(self,
                           selector: #selector(playerItemNoteHandler(note:)),
                           name: note, object: nil)
        }
        
        let audioSessionNotes = [AVAudioSession.interruptionNotification,
                                 AVAudioSession.routeChangeNotification,
                                 AVAudioSession.mediaServicesWereLostNotification,
                                 AVAudioSession.mediaServicesWereResetNotification,
                                 AVAudioSession.silenceSecondaryAudioHintNotification] as [NSNotification.Name]
        for note in audioSessionNotes {
            nc.addObserver(self,
                           selector: #selector(audioSessionNoteHandler(note:)),
                           name: note, object: nil)
        }
        player.addObserver(self, forKeyPath: #keyPath(AVPlayer.currentItem), options: [.new], context: &observerContext)

    }

    
    @objc func audioSessionNoteHandler(note: Notification) {
        switch note.name {
            /* Registered listeners will be notified when the system has interrupted the audio session and when
             the interruption has ended.  Check the notification's userInfo dictionary for the interruption type -- either begin or end.
             In the case of an end interruption notification, check the userInfo dictionary for AVAudioSessionInterruptionOptions that
             indicate whether audio playback should resume.
             In cases where the interruption is a consequence of the application being suspended, the info dictionary will contain
             AVAudioSessionInterruptionWasSuspendedKey, with the boolean value set to true.
             */
        case AVAudioSession.interruptionNotification:
            print("AVAudioSession.interruption")
            break
        
            /* Registered listeners will be notified when a route change has occurred.  Check the notification's userInfo dictionary for the
             route change reason and for a description of the previous audio route.
             */
        case AVAudioSession.routeChangeNotification:
            if let userInfo = note.userInfo {
                if let reason = userInfo[AVAudioSessionRouteChangeReasonKey] as? Int  {
                    if reason == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.hashValue {
                        // headphones plugged out
                        audioPlay?.isPlaying = true
                        player.play()
                    }
                }
            }
            print("AVAudioSession.routeChange")
            break
        case AVAudioSession.mediaServicesWereLostNotification: // item has failed to play to its end time
            print("AVAudioSession.mediaServicesWereLost")
            break
        case AVAudioSession.mediaServicesWereResetNotification: // media did not arrive in time to continue playback
            print("AVAudioSession.mediaServicesWereReset")
            break
        case AVAudioSession.silenceSecondaryAudioHintNotification: // a new access log entry has been added
            print("AVAudioSession.silenceSecondaryAudioHint")
            break
        default:
            print("AVAudioSession.default")
            break
        }
    }
    
    @objc func playerItemNoteHandler(note: Notification) {
        switch note.name {
        case .AVPlayerItemTimeJumped:
            print("AVPlayerItemTimeJumped")
            break
        case .AVPlayerItemDidPlayToEndTime: // item has played to its end time
            print("AVPlayerItemDidPlayToEndTime")
            break
        case .AVPlayerItemFailedToPlayToEndTime: // item has failed to play to its end time
            print("AVPlayerItemFailedToPlayToEndTime")
            break
        case .AVPlayerItemPlaybackStalled: // media did not arrive in time to continue playback
            print("AVPlayerItemPlaybackStalled")
            break
        case .AVPlayerItemNewAccessLogEntry: // a new access log entry has been added
            print("AVPlayerItemNewAccessLogEntry")
            break
        case .AVPlayerItemNewErrorLogEntry: // a new error log entry has been added
            print("AVPlayerItemNewErrorLogEntry")
            break
        default:
            break
        }
    }
    
    public func getCurrentTime() -> TimeInterval {
        if let currentItem = player.currentItem,
            currentItem.duration.isValid && currentItem.duration.isNumeric {
            print("audio currentTime \(CMTimeGetSeconds(currentItem.currentTime()))")
            let currentTime = TimeInterval(CMTimeGetSeconds(currentItem.currentTime()))
            audioPlay?.currentTime = currentTime
            if audioPlay?.hasDuration == false {
                delegate?.streamPlaybackManager(self, playerCurrentItemDidChange: player)
            }
            audioPlay?.hasDuration = true
            return currentTime
        }
        return 0
    }
    
    public func getTotalTime() -> TimeInterval {
        if let currentItem = player.currentItem,
            currentItem.duration.isValid && currentItem.duration.isNumeric {
            print("audio duration \(CMTimeGetSeconds(currentItem.duration))")
            print("audio currentTime \(CMTimeGetSeconds(currentItem.currentTime()))")
            return TimeInterval(CMTimeGetSeconds(currentItem.duration))
        }
        return 0
    }

    func isPlaying(url: String? = nil) -> Bool {
        return isReadyToPlay(url: url ?? audioPlay?.urlString) && audioPlay?.isPlaying ?? false
    }
    
    func isReadyToPlay(url: String?) -> Bool {
        return isTryingToPlay(url: url) && readyForPlayback
    }
    
    func isTryingToPlay(url: String?) -> Bool {
        return audioPlay?.urlString == url
    }
    
    private func reload() {
        readyForPlayback = false
        let urlAsset = audioPlay?.urlAsset()
        urlAsset?.resourceLoader.setDelegate(nil, queue: .main)
        if ((urlAsset?.observationInfo) != nil) {
            urlAsset?.removeObserver(self, forKeyPath: #keyPath(AVURLAsset.isPlayable), context: &observerContext)
        }
        
        audioPlay?.isDownloading = false
        if let audioUrl = audioPlay?.downloadFiles?.popLast() {
            audioPlay?.urlString = audioUrl
        }
        
        if let urlAsset = audioPlay?.urlAsset() {
            urlAsset.resourceLoader.setDelegate(self, queue: .main)
            urlAsset.addObserver(self, forKeyPath: #keyPath(AVURLAsset.isPlayable), options: [.initial, .new], context: &observerContext)
        }
    }
    
    func canStepBackward() -> Bool {
        return hasDuration(url: audioPlay?.urlString)
    }
    
    func canStepForward() -> Bool {
        return hasDuration(url: audioPlay?.urlString)
    }
    
    func canGoToStart() -> Bool {
        return hasDuration(url: audioPlay?.urlString)
    }
    
    func canGoToEnd() -> Bool {
        return hasDuration(url: audioPlay?.urlString)
    }
    
    func hasDuration(url: String?) -> Bool {
        return isTryingToPlay(url: url) && audioPlay?.hasDuration ?? false
    }
    
    func pause() {
        delegate?.streamPlaybackManager(self, playerReadyToPlay: player, isPlaying: false)
        audioPlay?.isPlaying = false
        player.pause()
    }
    
    func forward() {
        if canStepForward() {
            let position = getCurrentTime() + 60
            playPosition(position: position)
        }
    }
    
    func backward() {
        if canStepBackward() {
            let position = getCurrentTime() - 60
            playPosition(position: position)
        }
    }
    
    func seekEnd() {
        if canGoToEnd() {
            let position = getTotalTime() - 60
            playPosition(position: position)
        }
    }
    
    func progress() -> Float {
        let total = getTotalTime()
        if total > 0 {
            return Float(getCurrentTime() / total)
        }
        return 0
    }
    
    func playCurrentPosition() {
        setupNowPlaying()
        setupRemoteCommandCenter()
        delegate?.streamPlaybackManager(self, playerReadyToPlay: player, isPlaying: true)
        
        let position = audioPlay?.currentTime ?? 0.0
        if position == 0.0 {
            audioPlay?.isPlaying = true
            player.play()
        }
        else {
            playPosition(position: position)
        }
    }
    
    func playPosition(position: Double) {
        var t = CMTime.zero
        if position > 0 {
            t = CMTime.init(seconds: position, preferredTimescale: 1)
        }
        player.seek(to: t, completionHandler: { response in
            self.audioPlay?.isPlaying = true
            self.player.play()
        })
    }
    
    func isPlayingUrl(urlString: String?) -> Bool {
        guard let urlString = urlString else { return false }
        return urlString == audioPlay?.urlString
    }

    /**
     Replaces the currently playing `Stream`, if any, with a new `Stream`. If nil
     is passed, `StreamPlaybackManager` will handle unloading the existing `Stream`
     and handle KVO cleanup.
     */
    func setAudioForPlayback(_ sender: AudioPlay?) {
        if  sender?.urlString != nil &&
            sender?.urlString?.count ?? 0 > 0 &&
            self.audioPlay?.urlString == sender?.urlString {
            playCurrentPosition()
        }
        else {
            audioPlay = sender
        }
    }
    
     // MARK: KVO
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard context == &observerContext else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
            return
        }
        
        guard let keyPath = keyPath else {
            return
        }
        
        switch keyPath {
        case #keyPath(AVURLAsset.isPlayable):
            guard let urlAsset = audioPlay?.urlAsset(),
                urlAsset.isPlayable == true else {
                    if audioPlay?.downloadFiles?.count ?? 0 > 0 {
                        reload()
                        return
                    }
                    let error = JFError(code: Int(errno),
                                        desc: "Error",
                                        reason: "Player cannot play",
                                        suggestion: "Please check your internet connection",
                                        underError: nil)
                    
                    audioPlay?.error = error.message()
                    delegate?.streamPlaybackManager(self, playerError: error)
                    return
            }
            
            
            playerItem = AVPlayerItem(asset: urlAsset)
            player.replaceCurrentItem(with: playerItem)
        case #keyPath(AVPlayerItem.status):
            guard let playerItem = playerItem else { return }
            if playerItem.status == .readyToPlay {
                if !readyForPlayback {
                    readyForPlayback = true
                    playCurrentPosition()
                }
            }
            else if playerItem.status == .failed {
                // Check if the url could be downloaded (probably as .pls)
                if let urlString = audioPlay?.urlString,
                    let url = URL(string: urlString),
                    audioPlay?.isDownloading == false,
                    audioPlay?.downloadFiles == nil {
                    readyForPlayback = false
	
                    audioPlay?.isDownloading = true
                    let downloadTask = session.downloadTask(with: url)
                    downloadTask.taskDescription = audioPlay?.urlString
                    downloadTask.resume()
                }
                else if audioPlay?.downloadFiles?.count ?? 0 > 0 {
                    reload()
                    return
                }
                else {
                    let error = JFError(code: Int(errno),
                                        desc: "Error",
                                        reason: "Player failed",
                                        suggestion: "Please check your internet connection",
                                        underError: playerItem.error as NSError?)
                    audioPlay?.error = error.message()
                    delegate?.streamPlaybackManager(self, playerError: error)
                }
                return
            }
            
        case #keyPath(AVPlayer.currentItem):
            delegate?.streamPlaybackManager(self, playerCurrentItemDidChange: player)
            playCurrentPosition()

        default:
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }
    
    private func setupNowPlaying() {
        var nowPlayingInfo = [String : Any]()
        if let audioPlay = audioPlay {
            nowPlayingInfo[MPMediaItemPropertyArtist] = audioPlay.title
            nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = audioPlay.subTitle
            nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = 1
            if let placeholderImage = UIImage.init(named: "Locos_de_la_azotea") {
                nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork.init(boundsSize: placeholderImage.size) { (size) -> UIImage in
                    return placeholderImage
                }
                
                let iv = UIImageView.init(image: placeholderImage)
                
                if let imageUrl = audioPlay.thumbnailUrl,
                    let url = URL(string: imageUrl) {
                    iv.af_setImage(withURL: url, placeholderImage: placeholderImage)
                    if  let image = iv.image,
                        let imageCopy = image.copy() as? UIImage {
                        nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork.init(boundsSize: imageCopy.size) { (size) -> UIImage in
                            return imageCopy
                        }
                    }
                }
            }
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    private func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared();
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget {event in
            self.player.play()
            return .success
        }
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget {event in
            self.player.pause()
            return .success
        }
        commandCenter.bookmarkCommand.isEnabled = true
        commandCenter.bookmarkCommand.localizedTitle = "Bookmark"
        commandCenter.bookmarkCommand.addTarget { event in
            self.changeAudioBookmark()
            return .success
        }
        commandCenter.skipForwardCommand.isEnabled = true
        commandCenter.skipForwardCommand.addTarget { event in
            self.forward()
            return .success
        }
        commandCenter.skipBackwardCommand.isEnabled = true
        commandCenter.skipBackwardCommand.addTarget { event in
            self.backward()
            return .success
        }
        commandCenter.seekForwardCommand.isEnabled = true
        commandCenter.seekForwardCommand.addTarget { event in
            self.seekEnd()
            return .success
        }
        commandCenter.seekBackwardCommand.isEnabled = true
        commandCenter.seekBackwardCommand.addTarget { event in
            self.playPosition(position: 0)
            return .success
        }
        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.addTarget { event -> MPRemoteCommandHandlerStatus in
            if let event = event as? MPChangePlaybackPositionCommandEvent {
                self.playPosition(position: event.positionTime)
            }
            return .success
        }
    }

    func changeAudioBookmark() {
        
        guard let context = RestApi.instance.context else { fatalError() }
        guard let audioPlay = audioPlay else { return }
        BaseController.isBookmarkChanged = true
        
        context.performAndWait {
            var action : String = "*"
            if let bookmark = Bookmark.search(byUrl: audioPlay.urlString) {
                bookmark.remove()
                CloudKitManager.instance.remove(bookmark: bookmark)
                action = "-"
            }
            else if var bookmark = Bookmark.create() {
                action = "+"
                bookmark += audioPlay
                CloudKitManager.instance.save(bookmark: bookmark)
            }
            else {
                fatalError()
            }
            Analytics.logFunction(function: "bookmark",
                                  parameters: ["action": action as AnyObject,
                                               "title": audioPlay.title as AnyObject,
                                               "section": audioPlay.section as AnyObject,
                                               "url": audioPlay.urlString as AnyObject])
            
            CoreDataManager.instance.save()
        }
    }

}

/// AssetPlaybackDelegate provides a common interface for StreamPlaybackManager to provide callbacks to its delegate.
protocol AssetPlaybackDelegate: class {
    
    /// This is called when the internal AVPlayer in StreamPlaybackManager is ready to start playback.
    func streamPlaybackManager(_ streamPlaybackManager: StreamPlaybackManager, playerReadyToPlay player: AVPlayer, isPlaying: Bool)
    
    /// This is called when the internal AVPlayer's currentItem has changed.
    func streamPlaybackManager(_ streamPlaybackManager: StreamPlaybackManager, playerCurrentItemDidChange player: AVPlayer)
    
    /// This is called when the internal AVPlayer in StreamPlaybackManager finds an error.
    func streamPlaybackManager(_ streamPlaybackManager: StreamPlaybackManager, playerError error: JFError)

}

extension StreamPlaybackManager : AVAssetResourceLoaderDelegate {
    
    /*!
     @method         resourceLoader:shouldWaitForLoadingOfRequestedResource:
     @abstract        Invoked when assistance is required of the application to load a resource.
     @param         resourceLoader
     The instance of AVAssetResourceLoader for which the loading request is being made.
     @param         loadingRequest
     An instance of AVAssetResourceLoadingRequest that provides information about the requested resource.
     @result         YES if the delegate can load the resource indicated by the AVAssetResourceLoadingRequest; otherwise NO.
     @discussion
     Delegates receive this message when assistance is required of the application to load a resource. For example, this method is invoked to load decryption keys that have been specified using custom URL schemes.
     If the result is YES, the resource loader expects invocation, either subsequently or immediately, of either -[AVAssetResourceLoadingRequest finishLoading] or -[AVAssetResourceLoadingRequest finishLoadingWithError:]. If you intend to finish loading the resource after your handling of this message returns, you must retain the instance of AVAssetResourceLoadingRequest until after loading is finished.
     If the result is NO, the resource loader treats the loading of the resource as having failed.
     Note that if the delegate's implementation of -resourceLoader:shouldWaitForLoadingOfRequestedResource: returns YES without finishing the loading request immediately, it may be invoked again with another loading request before the prior request is finished; therefore in such cases the delegate should be prepared to manage multiple loading requests.
     
     If an AVURLAsset is added to an AVContentKeySession object and a delegate is set on its AVAssetResourceLoader, that delegate's resourceLoader:shouldWaitForLoadingOfRequestedResource: method must specify which custom URL requests should be handled as content keys. This is done by returning YES and passing either AVStreamingKeyDeliveryPersistentContentKeyType or AVStreamingKeyDeliveryContentKeyType into -[AVAssetResourceLoadingContentInformationRequest setContentType:] and then calling -[AVAssetResourceLoadingRequest finishLoading].
     
     */
    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
        return true
    }
    
    
    /*!
     @method         resourceLoader:shouldWaitForRenewalOfRequestedResource:
     @abstract        Invoked when assistance is required of the application to renew a resource.
     @param         resourceLoader
     The instance of AVAssetResourceLoader for which the loading request is being made.
     @param         renewalRequest
     An instance of AVAssetResourceRenewalRequest that provides information about the requested resource.
     @result         YES if the delegate can renew the resource indicated by the AVAssetResourceLoadingRequest; otherwise NO.
     @discussion
     Delegates receive this message when assistance is required of the application to renew a resource previously loaded by resourceLoader:shouldWaitForLoadingOfRequestedResource:. For example, this method is invoked to renew decryption keys that require renewal, as indicated in a response to a prior invocation of resourceLoader:shouldWaitForLoadingOfRequestedResource:.
     If the result is YES, the resource loader expects invocation, either subsequently or immediately, of either -[AVAssetResourceRenewalRequest finishLoading] or -[AVAssetResourceRenewalRequest finishLoadingWithError:]. If you intend to finish loading the resource after your handling of this message returns, you must retain the instance of AVAssetResourceRenewalRequest until after loading is finished.
     If the result is NO, the resource loader treats the loading of the resource as having failed.
     Note that if the delegate's implementation of -resourceLoader:shouldWaitForRenewalOfRequestedResource: returns YES without finishing the loading request immediately, it may be invoked again with another loading request before the prior request is finished; therefore in such cases the delegate should be prepared to manage multiple loading requests.
     
     If an AVURLAsset is added to an AVContentKeySession object and a delegate is set on its AVAssetResourceLoader, that delegate's resourceLoader:shouldWaitForRenewalOfRequestedResource:renewalRequest method must specify which custom URL requests should be handled as content keys. This is done by returning YES and passing either AVStreamingKeyDeliveryPersistentContentKeyType or AVStreamingKeyDeliveryContentKeyType into -[AVAssetResourceLoadingContentInformationRequest setContentType:] and then calling -[AVAssetResourceLoadingRequest finishLoading].
     */
    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForRenewalOfRequestedResource renewalRequest: AVAssetResourceRenewalRequest) -> Bool {
        return true
    }
    
    
    /*!
     @method         resourceLoader:didCancelLoadingRequest:
     @abstract        Informs the delegate that a prior loading request has been cancelled.
     @param         loadingRequest
     The loading request that has been cancelled.
     @discussion    Previously issued loading requests can be cancelled when data from the resource is no longer required or when a loading request is superseded by new requests for data from the same resource. For example, if to complete a seek operation it becomes necessary to load a range of bytes that's different from a range previously requested, the prior request may be cancelled while the delegate is still handling it.
     */
    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, didCancel loadingRequest: AVAssetResourceLoadingRequest) {
        print("resourceLoader didCancel loadingRequest")
    }
    
    
    /*!
     @method         resourceLoader:shouldWaitForResponseToAuthenticationChallenge:
     @abstract        Invoked when assistance is required of the application to respond to an authentication challenge.
     @param         resourceLoader
     The instance of AVAssetResourceLoader asking for help with an authentication challenge.
     @param         authenticationChallenge
     An instance of NSURLAuthenticationChallenge.
     @discussion
     Delegates receive this message when assistance is required of the application to respond to an authentication challenge.
     If the result is YES, the resource loader expects you to send an appropriate response, either subsequently or immediately, to the NSURLAuthenticationChallenge's sender, i.e. [authenticationChallenge sender], via use of one of the messages defined in the NSURLAuthenticationChallengeSender protocol (see NSAuthenticationChallenge.h). If you intend to respond to the authentication challenge after your handling of -resourceLoader:shouldWaitForResponseToAuthenticationChallenge: returns, you must retain the instance of NSURLAuthenticationChallenge until after your response has been made.
     */
    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForResponseTo authenticationChallenge: URLAuthenticationChallenge) -> Bool {
        return true
    }
    
    
    /*!
     @method         resourceLoader:didCancelAuthenticationChallenge:
     @abstract        Informs the delegate that a prior authentication challenge has been cancelled.
     @param         authenticationChallenge
     The authentication challenge that has been cancelled.
     */
    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, didCancel authenticationChallenge: URLAuthenticationChallenge) {
        print("resourceLoader didCancel authenticationChallenge")
    }
}

extension StreamPlaybackManager: URLSessionDelegate, URLSessionDownloadDelegate {
    
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        print("responde = \(response)")
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        if totalBytesExpectedToWrite > 0 {
            let progress = Float(totalBytesWritten) / Float(totalBytesExpectedToWrite)
            print("Progress \(downloadTask.taskIdentifier) \(downloadTask.taskDescription ?? "") \(progress)")
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        print("\(downloadTask.taskIdentifier) \(downloadTask.taskDescription ?? "") -> Download finished: \(location)")
        print("fileName: \(location)")
        if downloadTask.taskDescription == audioPlay?.urlString {
            do {
                let data = try Data(contentsOf: location, options: .mappedIfSafe)

                audioPlay?.downloadFiles = [String]()
                if let files = String.init(data: data, encoding: .ascii)?.components(separatedBy: "\n") {
                    for file in files {
                        if file.count > 0 {
                            audioPlay?.downloadFiles?.append(file)
                        }
                    }
                    self.reload()
                }
                else {
                    let errorjf = JFError(code: Int(errno),
                                        desc: "Error",
                                        reason: "Audio Session failed",
                                        suggestion: "Please check the audio in your device",
                                        underError: nil)
                    audioPlay?.error = errorjf.message()
                    delegate?.streamPlaybackManager(self, playerError: errorjf)
                    return
                }
            }
            catch {
                let errorjf = JFError(code: Int(errno),
                                    desc: "Error",
                                    reason: "Audio Session failed",
                                    suggestion: "Please check the audio in your device",
                                    underError: error as NSError)
                
                delegate?.streamPlaybackManager(self, playerError: errorjf)
            }

        }
    }
    
}

