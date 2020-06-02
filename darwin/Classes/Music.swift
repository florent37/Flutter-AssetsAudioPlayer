#if canImport(UIKit)
    import Flutter
    import AVFoundation
    import UIKit
#elseif os(OSX)
    import FlutterMacOS
#endif

import MediaPlayer

struct NotificationSettings : Equatable {
    let nextEnabled: Bool
    let playPauseEnabled: Bool
    let prevEnabled: Bool
    let seekBarEnabled: Bool
    
    static func ==(lhs: NotificationSettings, rhs: NotificationSettings) -> Bool {
        return
            lhs.nextEnabled == rhs.nextEnabled &&
                lhs.playPauseEnabled == rhs.playPauseEnabled &&
                lhs.prevEnabled == rhs.prevEnabled &&
                lhs.seekBarEnabled == rhs.seekBarEnabled
    }
    init() {
        self.nextEnabled = true
        self.playPauseEnabled = true
        self.prevEnabled = true
        self.seekBarEnabled = true
    }

    init(nextEnabled: Bool, playPauseEnabled: Bool, prevEnabled: Bool, seekBarEnabled: Bool) {
        self.nextEnabled = nextEnabled
        self.playPauseEnabled = playPauseEnabled
        self.prevEnabled = prevEnabled
        self.seekBarEnabled = seekBarEnabled
    }
}

func notificationSettings(from: NSDictionary) -> NotificationSettings {
    return NotificationSettings(
        nextEnabled: from["notif.settings.nextEnabled"] as? Bool ?? true,
        playPauseEnabled: from["notif.settings.playPauseEnabled"] as? Bool ?? true,
        prevEnabled: from["notif.settings.prevEnabled"] as? Bool ?? true,
        seekBarEnabled: from["notif.settings.seekBarEnabled"] as? Bool ?? true
    )
}

struct AudioMetas : Equatable {
    var title: String?
    var artist: String?
    var album: String?
    var image: String?
    var imageType: String?
    var imagePackage: String?
    
    init(title: String?, artist: String?, album: String?, image: String?, imageType: String?, imagePackage: String?) {
        self.title = title
        self.artist = artist
        self.album = album
        self.image = image
        self.imageType = imageType
        self.imagePackage = imagePackage
    }
    
    static func ==(lhs: AudioMetas, rhs: AudioMetas) -> Bool {
        return
            lhs.title == rhs.title &&
                lhs.artist == rhs.artist &&
                lhs.album == rhs.album &&
                lhs.image == rhs.image &&
                lhs.imageType == rhs.imageType &&
                lhs.imagePackage == rhs.imagePackage
    }
}

public class Player : NSObject, AVAudioPlayerDelegate {
    
    let channel: FlutterMethodChannel
    let registrar: FlutterPluginRegistrar
    var player: AVPlayer?
    
    var observerStatus: [NSKeyValueObservation] = []
    
    var displayMediaPlayerNotification = false
    var audioMetas : AudioMetas?
    var _playingPath: String?
    var _lastOpenedPath: String?
    var notificationSettings: NotificationSettings?
    
    init(channel: FlutterMethodChannel, registrar: FlutterPluginRegistrar) {
        self.channel = channel
        self.registrar = registrar
    }
    
    func log(_ message: String){
        channel.invokeMethod("log", arguments: message)
    }
    
    func getUrlByType(path: String, audioType: String, assetPackage: String?) -> URL? {
        var url : URL
        
        if(audioType == "network" || audioType == "liveStream"){
            let urlStr : String = path.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
            if let u = URL(string: urlStr) {
                return u
            } else {
                print("Couldn't parse myURL = \(urlStr)")
                return nil
            }
            
        } else if(audioType == "file"){
            var localPath = path
            //if(localPath.starts(with: "/")){ //if alreeady starts with "file://", do not add
            //    localPath = "file:/" + localPath
            //}
            if(!localPath.starts(with: "file://")){ //if already starts with "file://", do not add
                localPath = "file://" + localPath
            }
            let urlStr : String = localPath.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
            if let u = URL(string: urlStr) {
                print(u)
                return u
            } else {
                print("Couldn't parse myURL = \(urlStr)")
                return nil
            }
        }  else { //asset
            #if os(iOS) //for now it's not available on mac, we will make a copy from flutter of the asset to tmp file
            var assetKey: String
            if(assetPackage != nil && !assetPackage!.isEmpty){
                assetKey = self.registrar.lookupKey(forAsset: path, fromPackage: assetPackage!)
            } else {
                assetKey = self.registrar.lookupKey(forAsset: path)
            }
            
            guard let path = Bundle.main.path(forResource: assetKey, ofType: nil) else {
                return nil
            }
            
            url = URL(fileURLWithPath: path)
            return url
            #else
            return nil
            #endif
        }
    }
    
    #if os(iOS)
    func getAudioCategory(respectSilentMode: Bool, showNotification: Bool) ->  AVAudioSession.Category {
        if(showNotification) {
            return AVAudioSession.Category.playback
        } else if(respectSilentMode) {
            return AVAudioSession.Category.soloAmbient
        } else {
            return AVAudioSession.Category.playback
        }
    }
    #endif
    
    #if os(iOS)
    var targets: [String:Any] = [:]
    
    func setupMediaPlayerNotificationView() {
         
        UIApplication.shared.beginReceivingRemoteControlEvents()
        let commandCenter = MPRemoteCommandCenter.shared()
        
            // Fallback on earlier versions
        
        
        self.updateNotif()
        

        self.deinitMediaPlayerNotifEvent()
        // Add handler for Play Command
        commandCenter.playCommand.isEnabled = (self.notificationSettings ?? NotificationSettings()).playPauseEnabled
        self.targets["play"] = commandCenter.playCommand.addTarget { [unowned self] event in
            self.channel.invokeMethod(Music.METHOD_PLAY_OR_PAUSE, arguments: [])
            return .success
        }
        
        // Add handler for Pause Command
        commandCenter.pauseCommand.isEnabled = (self.notificationSettings ?? NotificationSettings()).playPauseEnabled
        self.targets["pause"] = commandCenter.pauseCommand.addTarget { [unowned self] event in
            self.channel.invokeMethod(Music.METHOD_PLAY_OR_PAUSE, arguments: [])
            return .success
        }
        
        // Add handler for Pause Command
        commandCenter.previousTrackCommand.isEnabled = (self.notificationSettings ?? NotificationSettings()).prevEnabled
        self.targets["prev"] = commandCenter.previousTrackCommand.addTarget { [unowned self] event in
            self.channel.invokeMethod(Music.METHOD_PREV, arguments: [])
            
            return .success
        }
                
        // Add handler for Pause Command
        commandCenter.nextTrackCommand.isEnabled = (self.notificationSettings ?? NotificationSettings()).nextEnabled
        self.targets["next"] = commandCenter.nextTrackCommand.addTarget { [unowned self] event in
            self.channel.invokeMethod(Music.METHOD_NEXT, arguments: [])
            
            return .success
        }
        
        //https://stackoverflow.com/questions/34563451/set-mpnowplayinginfocenter-with-other-background-audio-playing
        //This isn't currently possible in iOS. Even just changing your category options to .MixWithOthers causes your nowPlayingInfo to be ignored.
        do {
            if #available(iOS 10.0, *) {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
                try AVAudioSession.sharedInstance().setActive(true)
            } else {
                try AVAudioSession.sharedInstance().setCategory(.playback, options: [])
                try AVAudioSession.sharedInstance().setActive(true)
            }
        } catch let error {
            print(error)
        }
    }
    
    func deinitMediaPlayerNotifEvent() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        if let t = self.targets["play"] {
            commandCenter.playCommand.removeTarget(t );
        }
        if let t = self.targets["pause"] {
            commandCenter.pauseCommand.removeTarget(t);
        }
        if let t = self.targets["prev"] {
            commandCenter.previousTrackCommand.removeTarget(t);
        }
        if let t = self.targets["next"] {
            commandCenter.nextTrackCommand.removeTarget(t);
        }
        self.targets.removeAll()
    }
    
    var nowPlayingInfo = [String: Any]()
    #endif
    
    #if os(iOS)
    func updateNotif() {
        if(!self.displayMediaPlayerNotification){
            return
        }
        
        let audioMetas : AudioMetas? = self.audioMetas
        
        self.nowPlayingInfo.removeAll()
        
        if let t = audioMetas?.title {
            self.nowPlayingInfo[MPMediaItemPropertyTitle] = t
        } else {
            self.nowPlayingInfo[MPMediaItemPropertyTitle] = ""
        }
        
        if let art = audioMetas?.artist {
            self.nowPlayingInfo[MPMediaItemPropertyArtist] = art
        } else {
            self.nowPlayingInfo[MPMediaItemPropertyArtist] = ""
        }
        
        if let alb = audioMetas?.album {
            self.nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = alb
        } else {
            nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = ""
        }

        if ((self.notificationSettings ?? NotificationSettings()).seekBarEnabled) {
            self.nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = self.currentSongDuration
            self.nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = _currentTime
        } else {
            self.nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = 0
            self.nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = 0
        }

        self.nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = 0
        
        
        print(self.nowPlayingInfo.description)
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = self.nowPlayingInfo
        
        //load image async
        if let imageMetasType = self.audioMetas?.imageType {
            if let imageMetas = self.audioMetas?.image {
                if #available(iOS 10.0, *) {
                    if(imageMetasType == "asset") {
                        DispatchQueue.global().async {
                            var imageKey : String
                            if(self.audioMetas?.imagePackage != nil){
                                imageKey = self.registrar.lookupKey(forAsset: imageMetas, fromPackage: self.audioMetas!.imagePackage!)
                            } else {
                                imageKey = self.registrar.lookupKey(forAsset: imageMetas)
                            }
                            if(!imageKey.isEmpty){
                                if let imagePath = Bundle.main.path(forResource: imageKey, ofType: nil) {
                                    if(!imagePath.isEmpty){
                                        let image: UIImage = UIImage(contentsOfFile: imagePath)!
                                        DispatchQueue.main.async {
                                            if(self.audioMetas == audioMetas){ //always the sam song ?
                                                self.nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size, requestHandler: { (size) -> UIImage in
                                                    return image
                                                })
                                                MPNowPlayingInfoCenter.default().nowPlayingInfo = self.nowPlayingInfo
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    } else { //network or else (file, but not on ios...)
                        DispatchQueue.global().async {
                            if let url = URL(string: imageMetas)  {
                                if let data = try? Data.init(contentsOf: url), let image = UIImage(data: data) {
                                    let artwork = MPMediaItemArtwork(boundsSize: image.size, requestHandler: { (_ size : CGSize) -> UIImage in
                                        return image
                                    })
                                    DispatchQueue.main.async {
                                        if(self.audioMetas == audioMetas){ //always the sam song ?
                                            print(self.nowPlayingInfo.description)
                                            
                                            self.nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
                                            MPNowPlayingInfoCenter.default().nowPlayingInfo = self.nowPlayingInfo
                                        }
                                    }
                                }
                            }
                        }
                    }
                } else {
                    // Fallback on earlier versions
                }
            }
        }
    }
    #endif
    
    class SlowMoPlayerItem: AVPlayerItem {
        
        override var canPlaySlowForward: Bool {
            return true
        }
        
        override var canPlayReverse: Bool {
            return true
        }
        
        override var canPlayFastForward: Bool {
            return true
        }
        
        override var canPlayFastReverse: Bool {
            return true
        }
        
        override var canPlaySlowReverse: Bool {
            return true
        }
    }
    
    func onAudioUpdated(path: String, audioMetas: AudioMetas) {
        if(_playingPath == path || (_playingPath == nil && _lastOpenedPath == path)){
            self.audioMetas = audioMetas
            #if os(iOS)
            updateNotif()
            #endif
        }
    }
    
    var currentSongDuration : Float64 = Float64(0.0)

    func open(assetPath: String,
              assetPackage: String?,
              audioType: String,
              autoStart: Bool,
              volume: Double,
              seek: Int?,
              respectSilentMode: Bool,
              audioMetas: AudioMetas,
              displayNotification: Bool,
              notificationSettings: NotificationSettings,
              playSpeed: Double,
              result: @escaping FlutterResult
    ){
        self.stop();
        guard let url = self.getUrlByType(path: assetPath, audioType: audioType, assetPackage: assetPackage) else {
            log("resource not found \(assetPath)")
            result("");
            return
        }
        
        do {
            #if os(iOS)
            let category = getAudioCategory(respectSilentMode: respectSilentMode, showNotification: displayNotification)
            let mode = AVAudioSession.Mode.default
            
            
            print("category " + category.rawValue);
            print("mode " + mode.rawValue);
            print("displayNotification " + displayNotification.description);
            
            //        log("url: "+url.absoluteString)
            /* set session category and mode with options */
            if #available(iOS 10.0, *) {
                try AVAudioSession.sharedInstance().setCategory(category, mode: mode, options: [.mixWithOthers])
                try AVAudioSession.sharedInstance().setActive(true)
                
            } else {
                
                try AVAudioSession.sharedInstance().setCategory(category, options: .mixWithOthers)
                try AVAudioSession.sharedInstance().setActive(true)
                
            }
            #endif
            
            let item = SlowMoPlayerItem(url: url)
            self.player = AVPlayer(playerItem: item)
            
            self.displayMediaPlayerNotification = displayNotification
            self.notificationSettings = notificationSettings
            self.audioMetas = audioMetas
            
            self._lastOpenedPath = assetPath
            
            NotificationCenter.default.addObserver(self, selector: #selector(self.playerDidFinishPlaying(note:)), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: item)
            
            observerStatus.append( item.observe(\.isPlaybackBufferEmpty, options: [.new]) { [weak self] (_, _) in
                // show buffering
                self?.setBuffering(true)
            })
            
            observerStatus.append( item.observe(\.isPlaybackLikelyToKeepUp, options: [.new]) { [weak self] (_, _) in
                // hide buffering
                self?.setBuffering(false)
            })
            
            observerStatus.append( item.observe( \.isPlaybackBufferFull, options: [.new]) { [weak self] (_, _) in
                // hide buffering
                self?.setBuffering(false)
            })
            
            observerStatus.append( item.observe(\.status, changeHandler: { [weak self] (item, value) in
                
                switch item.status {
                case .unknown:
                    debugPrint("status: unknown")
                case .readyToPlay:
                    debugPrint("status: ready to play")
                    
                    if(audioType == "liveStream"){
                        self?.channel.invokeMethod(Music.METHOD_CURRENT, arguments: ["totalDurationMs": 0.0])
                        self?.currentSongDuration = Float64(0.0)
                        #if os(iOS)
                        self?.setupMediaPlayerNotificationView()
                        #endif
                    } else {
                        let audioDurationSeconds = CMTimeGetSeconds(item.duration)
                        let audioDurationMS = audioDurationSeconds * 1000
                        self?.channel.invokeMethod(Music.METHOD_CURRENT, arguments: ["totalDurationMs": audioDurationMS])
                        self?.currentSongDuration = audioDurationSeconds
                        #if os(iOS)
                        self?.setupMediaPlayerNotificationView()
                        #endif
                    }
                    
                    if(autoStart == true){
                        self?.play()
                    }
                    
                    self?.setVolume(volume: volume)
                    self?.setPlaySpeed(playSpeed: playSpeed)
                    
                    if(seek != nil){
                        self?.seek(to: seek!)
                    }
                    
                    self?._playingPath = assetPath
                    
                    result(nil)
                case .failed:
                    debugPrint("playback failed")
                    
                    result(FlutterError(
                        code: "PLAY_ERROR",
                        message: "Cannot play "+assetPath,
                        details: nil)
                    );
                @unknown default:
                    fatalError()
                }
            }))
            
            
            
            if(self.player == nil){
                //log("player is null");
                return
            }
            
            self.currentTime = 0
            self.playing = false
        } catch let error {
            result(FlutterError(
                code: "PLAY_ERROR",
                message: "Cannot play "+assetPath,
                details: error.localizedDescription)
            )
            log(error.localizedDescription)
            print(error.localizedDescription)
        }
    }
    
    private func setBuffering(_ value: Bool){
        self.channel.invokeMethod(Music.METHOD_IS_BUFFERING, arguments: value)
    }
    
    func seek(to: Int){
        let targetTime = CMTimeMakeWithSeconds(Double(to) / 1000.0, preferredTimescale: 1)
        self.player?.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero)
    }
    
    func setVolume(volume: Double){
        self.player?.volume = Float(volume)
        self.channel.invokeMethod(Music.METHOD_VOLUME, arguments: volume)
    }
    
    var _rate : Float = 1.0
    var rate : Float {
        get {
            return _rate
        }
        set(newValue) {
            if(_rate != newValue){
                _rate = newValue
                self.channel.invokeMethod(Music.METHOD_PLAY_SPEED, arguments: _rate)
            }
        }
    };
    
    func setPlaySpeed(playSpeed: Double){
        self.rate = Float(playSpeed)
        if(self._playing){
            self.player?.rate = self.rate
        }
    }
    
    func forwardRewind(speed: Double){
        //on ios we can have nevative speed
        self.player?.rate = Float(speed) //it does not changes self.rate here
        
        self.channel.invokeMethod(Music.METHOD_FORWARD_REWIND, arguments: speed)
    }
    
    func stop(){
        self.player?.pause()
        self.player?.rate = 0.0
        if(self.displayMediaPlayerNotification){
            #if os(iOS)
            if #available(iOS 13.0, *) {
                MPNowPlayingInfoCenter.default().playbackState = .stopped
            }
            self.nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = self.player?.rate
            MPNowPlayingInfoCenter.default().nowPlayingInfo = self.nowPlayingInfo
            #endif
        }
        self.player?.seek(to: CMTime.zero)
        self.player = nil   
        self.playing = false
        self.currentTimeTimer?.invalidate()
        #if os(iOS)
        self.deinitMediaPlayerNotifEvent()
        #endif
        NotificationCenter.default.removeObserver(self)
        self.observerStatus.forEach {
            $0.invalidate()
        }
        self.observerStatus.removeAll()
        #if os(iOS)
        self.nowPlayingInfo.removeAll()
        #endif
    }
    
    func play(){
        self.player?.play()
        self.player?.rate = self.rate
        self.currentTimeTimer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(updateTimer), userInfo: nil, repeats: true)
        self.currentTimeTimer?.fire()
        self.playing = true
        
        if(self.displayMediaPlayerNotification){
            #if os(iOS)
            if #available(iOS 13.0, *) {
                MPNowPlayingInfoCenter.default().playbackState = .playing
            }
            self.nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = self.player?.rate
            MPNowPlayingInfoCenter.default().nowPlayingInfo = self.nowPlayingInfo
            #endif
        }
    }
    
    var _currentTime : TimeInterval = 0
    private var currentTime : TimeInterval {
        get {
            return _currentTime
        }
        set(newValue) {
            if(_currentTime != newValue){
                _currentTime = newValue
                self.channel.invokeMethod(Music.METHOD_POSITION, arguments: self._currentTime)
                
                if(self.displayMediaPlayerNotification){
                    #if os(iOS)
                    self.nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = _currentTime
                    self.nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = self.player!.rate
                    MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
                    #endif
                }
            }
        }
    };
    
    var _playing : Bool = false
    var playing : Bool {
        get {
            return _playing
        }
        set(newValue) {
            _playing = newValue
            self.channel.invokeMethod(Music.METHOD_IS_PLAYING, arguments: self._playing)
        }
    };
    
    var currentTimeTimer: Timer?
    
    @objc public func playerDidFinishPlaying(note: NSNotification){
        self.channel.invokeMethod(Music.METHOD_FINISHED, arguments: true)
    }
    
    deinit {
        self.observerStatus.forEach {
            $0.invalidate()
        }
        self.observerStatus.removeAll()
        #if os(iOS)
        self.deinitMediaPlayerNotifEvent()
        #endif
        NotificationCenter.default.removeObserver(self)
    }
    
    func pause(){
        self.player?.pause()
        if(self.displayMediaPlayerNotification){
            #if os(iOS)
            self.nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = 0
            MPNowPlayingInfoCenter.default().nowPlayingInfo = self.nowPlayingInfo
            
            if #available(iOS 13.0, *) {
                MPNowPlayingInfoCenter.default().playbackState = .paused
            }
            #endif
        }
        self.playing = false
        self.currentTimeTimer?.invalidate()
    }
    
    @objc func updateTimer(){
        //log("updateTimer");
        if let p = self.player {
            if let currentItem = p.currentItem {
                self.currentTime = CMTimeGetSeconds(currentItem.currentTime())
            }
        }
    }
}

class Music : NSObject, FlutterPlugin {
    
    static let METHOD_POSITION = "player.position"
    static let METHOD_FINISHED = "player.finished"
    static let METHOD_IS_PLAYING = "player.isPlaying"
    static let METHOD_FORWARD_REWIND = "player.forwardRewind"
    static let METHOD_CURRENT = "player.current"
    static let METHOD_VOLUME = "player.volume"
    static let METHOD_IS_BUFFERING = "player.isBuffering"
    static let METHOD_PLAY_SPEED = "player.playSpeed"
    static let METHOD_NEXT = "player.next"
    static let METHOD_PREV = "player.prev"
    static let METHOD_PLAY_OR_PAUSE = "player.playOrPause"

    var players = Dictionary<String, Player>()
    
    func getOrCreatePlayer(id: String) -> Player {
        if let player = players[id] {
            return player
        } else {
            #if os(iOS)
            let newPlayer = Player(
                channel: FlutterMethodChannel(name: "assets_audio_player/"+id, binaryMessenger: registrar.messenger()),
                registrar: self.registrar
            )
            #else
            let newPlayer = Player(
                channel: FlutterMethodChannel(name: "assets_audio_player/"+id, binaryMessenger: registrar.messenger),
                registrar: self.registrar
            )
            #endif
            players[id] = newPlayer
            return newPlayer
        }
    }
    
    static func register(with registrar: FlutterPluginRegistrar) {
        
    }
    
    //public func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [AnyHashable : Any] = [:]) -> Bool {
    //    application.beginReceivingRemoteControlEvents()
    //    return true;
    //}
    
    let channel: FlutterMethodChannel
    let registrar: FlutterPluginRegistrar
    
    init(messenger: FlutterBinaryMessenger, registrar: FlutterPluginRegistrar) {
        self.channel = FlutterMethodChannel(name: "assets_audio_player", binaryMessenger: messenger);
        self.registrar = registrar
    }
    
    func start(){
        #if os(iOS)
        self.registrar.addApplicationDelegate(self)
        #endif
        
        channel.setMethodCallHandler({(call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
            //self.log(call.method + call.arguments.debugDescription)
            switch(call.method){
            case "isPlaying" :
                guard let args = call.arguments as? NSDictionary else {
                    result(FlutterError(
                        code: "METHOD_CALL",
                        message: call.method + " Arguments must be an NSDictionary",
                        details: nil)
                    );
                    break;
                }
                guard let id = args["id"] as? String else {
                    result(FlutterError(
                        code: "METHOD_CALL",
                        message: call.method + " Arguments[id] must be a String",
                        details: nil)
                    );
                    break;
                }
                result(self.getOrCreatePlayer(id: id).playing);
                break;
            case "play" :
                guard let args = call.arguments as? NSDictionary else {
                    result(FlutterError(
                        code: "METHOD_CALL",
                        message: call.method + " Arguments must be an NSDictionary",
                        details: nil)
                    );
                    break;
                }
                guard let id = args["id"] as? String else {
                    result(FlutterError(
                        code: "METHOD_CALL",
                        message: call.method + " Arguments[id] must be a String",
                        details: nil)
                    );
                    break;
                }
                self.getOrCreatePlayer(id: id)
                    .play();
                result(true);
                break;
                
            case "pause" :
                guard let args = call.arguments as? NSDictionary else {
                    result(FlutterError(
                        code: "METHOD_CALL",
                        message: call.method + " Arguments must be an NSDictionary",
                        details: nil)
                    );
                    break;
                }
                guard let id = args["id"] as? String else {
                    result(FlutterError(
                        code: "METHOD_CALL",
                        message: call.method + " Arguments[id] must be a String",
                        details: nil)
                    );
                    break;
                }
                self.getOrCreatePlayer(id: id)
                    .pause();
                result(true);
                break;
                
            case "stop" :
                guard let args = call.arguments as? NSDictionary else {
                    result(FlutterError(
                        code: "METHOD_CALL",
                        message: call.method + " Arguments must be an NSDictionary",
                        details: nil)
                    );
                    break;
                }
                guard let id = args["id"] as? String else {
                    result(FlutterError(
                        code: "METHOD_CALL",
                        message: call.method + " Arguments[id] must be a String",
                        details: nil)
                    );
                    break;
                }
                
                self.getOrCreatePlayer(id: id)
                    .stop();
                result(true);
                break;
            case "seek" :
                guard let args = call.arguments as? NSDictionary else {
                    result(FlutterError(
                        code: "METHOD_CALL",
                        message: call.method + " Arguments must be an NSDictionary",
                        details: nil)
                    );
                    break;
                }
                guard let id = args["id"] as? String else {
                    result(FlutterError(
                        code: "METHOD_CALL",
                        message: call.method + " Arguments[id] must be a String",
                        details: nil)
                    );
                    break;
                }
                guard let pos = args["to"] as? Int else {
                    result(FlutterError(
                        code: "METHOD_CALL",
                        message: call.method + " Arguments[to] must be a String",
                        details: nil)
                    );
                    break;
                }
                self.getOrCreatePlayer(id: id)
                    .seek(to: pos);
                result(true);
                break;
                
            case "volume" :
                guard let args = call.arguments as? NSDictionary else {
                    result(FlutterError(
                        code: "METHOD_CALL",
                        message: call.method + " Arguments must be an NSDictionary",
                        details: nil)
                    );
                    break;
                }
                guard let id = args["id"] as? String else {
                    result(FlutterError(
                        code: "METHOD_CALL",
                        message: call.method + " Arguments[id] must be a String",
                        details: nil)
                    );
                    break;
                }
                guard let volume = args["volume"] as? Double else {
                    result(FlutterError(
                        code: "METHOD_CALL",
                        message: call.method + " Arguments[volume] must be a String",
                        details: nil)
                    );
                    break;
                }
                self.getOrCreatePlayer(id: id)
                    .setVolume(volume: volume);
                result(true);
                break;
                
            case "playSpeed" :
                guard let args = call.arguments as? NSDictionary else {
                    result(FlutterError(
                        code: "METHOD_CALL",
                        message: call.method + " Arguments must be an NSDictionary",
                        details: nil)
                    );
                    break;
                }
                guard let id = args["id"] as? String else {
                    result(FlutterError(
                        code: "METHOD_CALL",
                        message: call.method + " Arguments[id] must be a String",
                        details: nil)
                    );
                    break;
                }
                guard let playSpeed = args["playSpeed"] as? Double else {
                    result(FlutterError(
                        code: "METHOD_CALL",
                        message: call.method + " Arguments[playSpeed] must be a String",
                        details: nil)
                    );
                    break;
                }
                self.getOrCreatePlayer(id: id)
                    .setPlaySpeed(playSpeed: playSpeed);
                result(true);
                break;
                
            case "forwardRewind" :
                guard let args = call.arguments as? NSDictionary else {
                    result(FlutterError(
                        code: "METHOD_CALL",
                        message: call.method + " Arguments must be an NSDictionary",
                        details: nil)
                    );
                    break;
                }
                guard let id = args["id"] as? String else {
                    result(FlutterError(
                        code: "METHOD_CALL",
                        message: call.method + " Arguments[id] must be a String",
                        details: nil)
                    );
                    break;
                }
                guard let speed = args["speed"] as? Double else {
                    result(FlutterError(
                        code: "METHOD_CALL",
                        message: call.method + " Arguments[speed] must be a String",
                        details: nil)
                    );
                    break;
                }
                self.getOrCreatePlayer(id: id)
                    .forwardRewind(speed: speed);
                result(true);
                break;
            case "onAudioUpdated" :
                guard let args = call.arguments as? NSDictionary else {
                    result(FlutterError(
                        code: "METHOD_CALL",
                        message: call.method + " Arguments must be an NSDictionary",
                        details: nil)
                    );
                    break;
                }
                guard let id = args["id"] as? String else {
                    result(FlutterError(
                        code: "METHOD_CALL",
                        message: call.method + " Arguments[id] must be a String",
                        details: nil)
                    );
                    break;
                }
                guard let path = args["path"] as? String else {
                    result(FlutterError(
                        code: "METHOD_CALL",
                        message: call.method + " Arguments[path] must be a String",
                        details: nil)
                    );
                    break;
                }
                
                //metas
                let songTitle = args["song.title"] as? String //can be null
                let songArtist = args["song.artist"] as? String //can be null
                let songAlbum = args["song.album"] as? String //can be null
                let songImage = args["song.image"] as? String //can be null
                let songImageType = args["song.imageType"] as? String //can be null
                let songImagePackage = args["song.imagePackage"] as? String //can be null
                
                //end-metas
                
                let audioMetas = AudioMetas(
                    title: songTitle,
                    artist: songArtist,
                    album: songAlbum,
                    image: songImage,
                    imageType: songImageType,
                    imagePackage: songImagePackage
                )

                self.getOrCreatePlayer(id: id).onAudioUpdated(path: path, audioMetas: audioMetas)
                result(true);
                break;
            case "open" :
                guard let args = call.arguments as? NSDictionary else {
                    result(FlutterError(
                        code: "METHOD_CALL",
                        message: call.method + " Arguments must be an NSDictionary",
                        details: nil)
                    );
                    break;
                }
                guard let id = args["id"] as? String else {
                    result(FlutterError(
                        code: "METHOD_CALL",
                        message: call.method + " Arguments[id] must be a String",
                        details: nil)
                    );
                    break;
                }
                guard let assetPath = args["path"] as? String else {
                    result(FlutterError(
                        code: "METHOD_CALL",
                        message: call.method + " Arguments[path] must be a String",
                        details: nil)
                    );
                    break;
                }
                
                let assetPackage = args["package"] as? String //can be null
                
                guard let audioType = args["audioType"] as? String else {
                    result(FlutterError(
                        code: "METHOD_CALL",
                        message: call.method + " Arguments[audioType] must be a String",
                        details: nil)
                    );
                    break;
                }
                guard let volume = args["volume"] as? Double else {
                    result(FlutterError(
                        code: "METHOD_CALL",
                        message: call.method + " Arguments[volume] must be a Double",
                        details: nil)
                    );
                    break;
                }
                let seek = args["seek"] as? Int //can be null
                guard let playSpeed = args["playSpeed"] as? Double else {
                    result(FlutterError(
                        code: "METHOD_CALL",
                        message: call.method + " Arguments[playSpeed] must be a Double",
                        details: nil)
                    );
                    break;
                }
                guard let autoStart = args["autoStart"] as? Bool else {
                    result(FlutterError(
                        code: "METHOD_CALL",
                        message: call.method + " Arguments[autoStart] must be a Bool",
                        details: nil)
                    );
                    break;
                }
                //metas
                let songTitle = args["song.title"] as? String //can be null
                let songArtist = args["song.artist"] as? String //can be null
                let songAlbum = args["song.album"] as? String //can be null
                let songImage = args["song.image"] as? String //can be null
                let songImageType = args["song.imageType"] as? String //can be null
                let songImagePackage = args["song.imagePackage"] as? String //can be null
                
                //end-metas
                let respectSilentMode = args["respectSilentMode"] as? Bool ?? false
                let displayNotification = args["displayNotification"] as? Bool ?? false
                
                let audioMetas = AudioMetas(
                    title: songTitle,
                    artist: songArtist,
                    album: songAlbum,
                    image: songImage,
                    imageType: songImageType,
                    imagePackage: songImagePackage
                )
                
                let notifSettings = notificationSettings(from: args)
                
                self.getOrCreatePlayer(id: id)
                    .open(
                        assetPath: assetPath,
                        assetPackage: assetPackage,
                        audioType: audioType,
                        autoStart: autoStart,
                        volume:volume,
                        seek: seek,
                        respectSilentMode: respectSilentMode,
                        audioMetas: audioMetas,
                        displayNotification: displayNotification,
                        notificationSettings: notifSettings,
                        playSpeed: playSpeed,
                        result: result
                );
                break;
                
            default:
                result(FlutterMethodNotImplemented);
                break;
                
            }
        })
    }
    
}

