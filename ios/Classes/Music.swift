import Flutter
import UIKit
import AVFoundation
import MediaPlayer

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
        }
    }
    
    func getAudioCategory(respectSilentMode: Bool) ->  AVAudioSession.Category {
        if(respectSilentMode) {
            return AVAudioSession.Category.soloAmbient
        } else {
            return AVAudioSession.Category.playback
        }
    }
    
    var targets: [String:Any] = [:]
    func setupMediaPlayerNotificationView(currentSongDuration: Any) {
        UIApplication.shared.beginReceivingRemoteControlEvents()
        let commandCenter = MPRemoteCommandCenter.shared()
        //commandCenter.playCommand.isEnabled = self.playing
        
        self.setupNotificationView(currentSongDuration: currentSongDuration)
        
        
        self.deinitMediaPlayerNotifEvent()
        // Add handler for Play Command
        self.targets["play"] = commandCenter.playCommand.addTarget { [unowned self] event in
            self.play();
            return .success
        }
        
        // Add handler for Pause Command
        self.targets["pause"] = commandCenter.pauseCommand.addTarget { [unowned self] event in
            self.pause();
            return .success
        }
        
        // Add handler for Pause Command
        self.targets["prev"] = commandCenter.previousTrackCommand.addTarget { [unowned self] event in
            self.channel.invokeMethod(Music.METHOD_PREV, arguments: [])
            
            return .success
        }
        
        // Add handler for Pause Command
        self.targets["next"] = commandCenter.nextTrackCommand.addTarget { [unowned self] event in
            self.channel.invokeMethod(Music.METHOD_NEXT, arguments: [])
            
            return .success
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
    
    func setupNotificationView(currentSongDuration: Any) {
        if(!self.displayMediaPlayerNotification){
            return
        }
        
        let audioMetas : AudioMetas? = self.audioMetas
        
        if let t = audioMetas?.title {
            nowPlayingInfo[MPMediaItemPropertyTitle] = t
        } else {
            nowPlayingInfo[MPMediaItemPropertyTitle] = ""
        }
        
        if let art = audioMetas?.artist {
            nowPlayingInfo[MPMediaItemPropertyArtist] = art
        } else {
            nowPlayingInfo[MPMediaItemPropertyArtist] = ""
        }
        
        if let alb = audioMetas?.album {
            nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = alb
        } else {
            nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = ""
        }
        
        
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = currentSongDuration
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = _currentTime
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = 0
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        
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
    
    func open(assetPath: String,
              assetPackage: String?,
              audioType: String,
              autoStart: Bool,
              volume: Double,
              seek: Int?,
              respectSilentMode: Bool,
              audioMetas: AudioMetas,
              displayNotification: Bool,
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
            //        log("url: "+url.absoluteString)
            /* set session category and mode with options */
            if #available(iOS 10.0, *) {
                
                try AVAudioSession.sharedInstance().setCategory(getAudioCategory(respectSilentMode: respectSilentMode), mode: AVAudioSession.Mode.default, options: [.mixWithOthers])
                try AVAudioSession.sharedInstance().setActive(true)
                
            } else {
                
                try AVAudioSession.sharedInstance().setCategory(getAudioCategory(respectSilentMode: respectSilentMode), options: .mixWithOthers)
                try AVAudioSession.sharedInstance().setActive(true)
                
            }
            
            let item = SlowMoPlayerItem(url: url)
            self.player = AVPlayer(playerItem: item)
            
            self.displayMediaPlayerNotification = displayNotification
            self.audioMetas = audioMetas
            
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
                    
                    
                    let audioDurationSeconds = CMTimeGetSeconds(item.duration) //CMTimeGetSeconds(asset.duration)
                    self?.channel.invokeMethod(Music.METHOD_CURRENT, arguments: ["totalDuration": audioDurationSeconds])
                    
                    self?.setupMediaPlayerNotificationView(currentSongDuration: audioDurationSeconds)
                    
                    if(autoStart == true){
                        self?.play()
                    }
                    
                    self?.setVolume(volume: volume)
                    self?.setPlaySpeed(playSpeed: playSpeed)
                    
                    if(seek != nil){
                        self?.seek(to: seek!)
                    }
                    
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
            result(error);
            log(error.localizedDescription)
            print(error.localizedDescription)
        }
    }
    
    private func setBuffering(_ value: Bool){
        self.channel.invokeMethod(Music.METHOD_IS_BUFFERING, arguments: value)
    }
    
    func seek(to: Int){
        let targetTime = CMTimeMakeWithSeconds(Double(to), preferredTimescale: 1)
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
        self.player?.seek(to: CMTime.zero)
        self.player?.rate = 0.0
        self.player = nil   
        self.playing = false
        self.currentTimeTimer?.invalidate()
        self.deinitMediaPlayerNotifEvent()
        NotificationCenter.default.removeObserver(self)
        self.observerStatus.forEach {
            $0.invalidate()
        }
        self.observerStatus.removeAll()
        self.nowPlayingInfo.removeAll()
    }
    
    func play(){
        self.player?.play()
        self.player?.rate = self.rate
        self.currentTimeTimer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(updateTimer), userInfo: nil, repeats: true)
        self.currentTimeTimer?.fire()
        self.playing = true
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
                    self.nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = _currentTime
                    self.nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = self.player!.rate
                    MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
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
        self.deinitMediaPlayerNotifEvent()
        NotificationCenter.default.removeObserver(self)
    }
    
    func pause(){
        self.player?.pause()
        if(self.displayMediaPlayerNotification){
            self.nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = 0
            MPNowPlayingInfoCenter.default().nowPlayingInfo = self.nowPlayingInfo
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
    
    var players = Dictionary<String, Player>()
    
    func getOrCreatePlayer(id: String) -> Player {
        if let player = players[id] {
            return player
        } else {
            let newPlayer = Player(
                channel: FlutterMethodChannel(name: "assets_audio_player/"+id, binaryMessenger: registrar.messenger()),
                registrar: self.registrar
            )
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
        self.registrar.addApplicationDelegate(self)
        
        channel.setMethodCallHandler({(call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
            //self.log(call.method + call.arguments.debugDescription)
            switch(call.method){
            case "isPlaying" :
                let args = call.arguments as! NSDictionary
                let id = args["id"] as! String
                result(self.getOrCreatePlayer(id: id).playing);
                break;
            case "play" :
                let args = call.arguments as! NSDictionary
                let id = args["id"] as! String
                self.getOrCreatePlayer(id: id)
                    .play();
                result(true);
                break;
                
            case "pause" :
                let args = call.arguments as! NSDictionary
                let id = args["id"] as! String
                self.getOrCreatePlayer(id: id)
                    .pause();
                result(true);
                break;
                
            case "stop" :
                let args = call.arguments as! NSDictionary
                let id = args["id"] as! String
                self.getOrCreatePlayer(id: id)
                    .stop();
                result(true);
                break;
            case "seek" :
                let args = call.arguments as! NSDictionary
                let id = args["id"] as! String
                let pos = args["to"] as! Int;
                self.getOrCreatePlayer(id: id)
                    .seek(to: pos);
                result(true);
                break;
                
            case "volume" :
                let args = call.arguments as! NSDictionary
                let id = args["id"] as! String
                let volume = args["volume"] as! Double;
                self.getOrCreatePlayer(id: id)
                    .setVolume(volume: volume);
                result(true);
                break;
                
            case "playSpeed" :
                let args = call.arguments as! NSDictionary
                let id = args["id"] as! String
                let playSpeed = args["playSpeed"] as! Double;
                self.getOrCreatePlayer(id: id)
                    .setPlaySpeed(playSpeed: playSpeed);
                result(true);
                break;
                
            case "forwardRewind" :
                let args = call.arguments as! NSDictionary
                let id = args["id"] as! String
                let speed = args["speed"] as! Double;
                self.getOrCreatePlayer(id: id)
                    .forwardRewind(speed: speed);
                result(true);
                break;
                
            case "open" :
                let args = call.arguments as! NSDictionary
                let id = args["id"] as! String
                let assetPath = args["path"] as! String
                let assetPackage = args["package"] as? String
                let audioType = args["audioType"] as! String
                let volume = args["volume"] as! Double
                let seek = args["seek"] as? Int
                let playSpeed = args["playSpeed"] as! Double
                let autoStart = args["autoStart"] as! Bool
                //metas
                let songTitle = args["song.title"] as? String
                let songArtist = args["song.artist"] as? String
                let songAlbum = args["song.album"] as? String
                let songImage = args["song.image"] as? String
                let songImageType = args["song.imageType"] as? String
                let songImagePackage = args["song.imagePackage"] as? String
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

