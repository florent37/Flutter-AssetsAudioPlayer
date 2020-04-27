import Flutter
import UIKit
import AVFoundation
import MediaPlayer

public class SwiftAssetsAudioPlayerPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let music = Music(messenger: registrar.messenger(), registrar: registrar)
    music.start()
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {

  }
}

struct AudioMetas {
    var title: String?
    var artist: String?
    var album: String?
    var image: String?
    var imageType: String?
    
    init(title: String?, artist: String?, album: String?, image: String?, imageType: String?) {
        self.title = title
        self.artist = artist
        self.album = album
        self.image = image
        self.imageType = imageType
    }
}

public class Player : NSObject, AVAudioPlayerDelegate {
    
    let channel: FlutterMethodChannel
    let registrar: FlutterPluginRegistrar
    var player: AVPlayer?
    
    var observerStatus: NSKeyValueObservation?
    
    var displayMediaPlayerNotification = false
    var audioMetas : AudioMetas?

    init(channel: FlutterMethodChannel, registrar: FlutterPluginRegistrar) {
        self.channel = channel
        self.registrar = registrar
    }
    
    func log(_ message: String){
        channel.invokeMethod("log", arguments: message)
    }
    
    func getUrlByType(path: String, audioType: String) -> URL? {
        var url : URL

        if(audioType == "network"){
            let urlStr : String = path.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
            if let u = URL(string: urlStr) {
                return u
            } else {
                print("Couldn't parse myURL = \(urlStr)")
                return nil
            }

        } else if(audioType == "file"){
            let urlStr : String = path.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
            if let u = URL(string: urlStr) {
                 return u
            } else {
                print("Couldn't parse myURL = \(urlStr)")
                return nil
            }
        }  else { //asset
            let assetKey = self.registrar.lookupKey(forAsset: path)

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
    
    func setupMediaPlayerNotificationView(currentSongDuration: Any) {
        UIApplication.shared.beginReceivingRemoteControlEvents()
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.isEnabled = self.playing
        
        self.setupNotificationView(currentSongDuration: currentSongDuration)

        // Add handler for Play Command
        commandCenter.playCommand.addTarget { [unowned self] event in
            self.play();
            return .success
        }
        
        // Add handler for Pause Command
        commandCenter.pauseCommand.addTarget { [unowned self] event in
            self.pause();
            return .success
        }
        
        // Add handler for Pause Command
        commandCenter.previousTrackCommand.addTarget { [unowned self] event in
            self.channel.invokeMethod(Music.METHOD_PREV, arguments: [])

            return .success
        }
        
        // Add handler for Pause Command
        commandCenter.nextTrackCommand.addTarget { [unowned self] event in
            self.channel.invokeMethod(Music.METHOD_NEXT, arguments: [])

            return .success
        }
    }
    
    func setupNotificationView(currentSongDuration: Any) {
        if(!self.displayMediaPlayerNotification){
            return
        }
        
        var nowPlayingInfo = [String: Any]()
        
        if let t = self.audioMetas?.title {
             nowPlayingInfo[MPMediaItemPropertyTitle] = t
        }
        if let art = self.audioMetas?.artist {
            nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = art
        }
        if let alb = self.audioMetas?.album {
            nowPlayingInfo[MPMediaItemPropertyArtist] = alb
        }
        
        if let imageMetasType = self.audioMetas?.imageType {
            if let imageMetas = self.audioMetas?.image {
                if #available(iOS 10.0, *) {
                    if(imageMetasType == "assets") {
                        let imageKey = self.registrar.lookupKey(forAsset: imageMetas)
                        let imagePath = Bundle.main.path(forResource: imageKey, ofType: nil)!
                        let image: UIImage = UIImage(contentsOfFile: imagePath)!

                        var nowPlayingInfo: [String:Any] = MPNowPlayingInfoCenter.default().nowPlayingInfo!
                        nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size, requestHandler: { (size) -> UIImage in
                            return image
                        })
                        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo

                    } else { //network or else (file, but not on ios...)
                        DispatchQueue.global().async {
                            if let url = URL(string: imageMetas)  {
                                if let data = try? Data.init(contentsOf: url), let image = UIImage(data: data) {
                                    let artwork = MPMediaItemArtwork(boundsSize: image.size, requestHandler: { (_ size : CGSize) -> UIImage in
                                        return image
                                    })
                                    DispatchQueue.main.async {
                                        
                                        var nowPlayingInfo: [String:Any] = MPNowPlayingInfoCenter.default().nowPlayingInfo!
                                        nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
                                        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
                                        
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

        
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = currentSongDuration
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = _currentTime
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = 0
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    func open(assetPath: String, audioType: String,
              autoStart: Bool, volume: Double,
              seek: Int?, respectSilentMode: Bool,
              audioMetas: AudioMetas, displayNotification: Bool,
              result: FlutterResult
    ){
        guard let url = self.getUrlByType(path: assetPath, audioType: audioType) else {
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

            let item = AVPlayerItem(url: url)
            self.player = AVPlayer(playerItem: item)
            
            self.displayMediaPlayerNotification = displayNotification
            self.audioMetas = audioMetas
            
            NotificationCenter.default.removeObserver(self)
            NotificationCenter.default.addObserver(self, selector: #selector(self.playerDidFinishPlaying(note:)), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: item)
                        
            observerStatus?.invalidate()
            observerStatus = item.observe(\.status, changeHandler: { [weak self] (item, value) in
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
                    
                     if(seek != nil){
                        self?.seek(to: seek!)
                     }
                    
                    
                 case .failed:
                     debugPrint("playback failed")
                 @unknown default:
                    fatalError()
                }
             })



            if(self.player == nil){
                //log("player is null");
                return
            }
                            
            self.currentTime = 0
            self.playing = false
            
            result(true);
        } catch let error {
            result(error);
            log(error.localizedDescription)
            print(error.localizedDescription)
        }
    }

    func seek(to: Int){
        let targetTime = CMTimeMakeWithSeconds(Double(to), preferredTimescale: 1)
        self.player?.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero)
    }
    
    func setVolume(volume: Double){
        self.player?.volume = Float(volume)
        self.channel.invokeMethod(Music.METHOD_VOLUME, arguments: volume)
    }
    
    func stop(){
        self.player?.pause()
        self.player?.seek(to: CMTime.zero)
        self.player?.rate = 0.0
        self.player = nil   
        self.playing = false
        self.currentTimeTimer?.invalidate()
    }
    
    func play(){
        self.player?.play()
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
                    var nowPlayingInfo: [String:Any] = MPNowPlayingInfoCenter.default().nowPlayingInfo!
                    nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = _currentTime
                    nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = self.player!.rate
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
        observerStatus?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
    
    func pause(){
        self.player?.pause()
        if(self.displayMediaPlayerNotification){
            var nowPlayingInfo: [String:Any] = MPNowPlayingInfoCenter.default().nowPlayingInfo!
            nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = 0
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
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
    static let METHOD_CURRENT = "player.current"
    static let METHOD_VOLUME = "player.volume"
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

        channel.setMethodCallHandler({(call: FlutterMethodCall, result: FlutterResult) -> Void in
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
                
            case "open" :
                let args = call.arguments as! NSDictionary
                let id = args["id"] as! String
                let assetPath = args["path"] as! String
                let audioType = args["audioType"] as! String
                let volume = args["volume"] as! Double
                let seek = args["seek"] as? Int
                let autoStart = args["autoStart"] as! Bool
                //metas
                let songTitle = args["song.title"] as? String
                let songArtist = args["song.artist"] as? String
                let songAlbum = args["song.album"] as? String
                let songImage = args["song.image"] as? String
                let songImageType = args["song.imageType"] as? String
                //end-metas
                let respectSilentMode = args["respectSilentMode"] as? Bool ?? false
                let displayNotification = args["displayNotification"] as? Bool ?? false
                
                let audioMetas = AudioMetas(title: songTitle, artist: songArtist, album: songAlbum, image: songImage, imageType: songImageType)
                
                self.getOrCreatePlayer(id: id)
                    .open(
                        assetPath: assetPath,
                        audioType: audioType,
                        autoStart: autoStart,
                        volume:volume,
                        seek: seek,
                        respectSilentMode: respectSilentMode,
                        audioMetas: audioMetas,
                        displayNotification: displayNotification,
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

