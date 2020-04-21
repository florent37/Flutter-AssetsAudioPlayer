import Flutter
import UIKit
import AVFoundation

public class SwiftAssetsAudioPlayerPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let music = Music(messenger: registrar.messenger(), registrar: registrar)
    music.start()
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {

  }
}

public class Player : NSObject, AVAudioPlayerDelegate {
    
    let channel: FlutterMethodChannel
    let registrar: FlutterPluginRegistrar
    var didSendDuration = false
    var player: AVPlayer?
    
    var autoPlay = false
    var observerStatus: NSKeyValueObservation?


    init(channel: FlutterMethodChannel, registrar: FlutterPluginRegistrar) {
        self.channel = channel
        self.registrar = registrar
    }
    
    func log(_ message: String){
        channel.invokeMethod("log", arguments: message)
    }
    
    func open(assetPath: String, audioType: String, autoStart: Bool, volume: Double, result: FlutterResult){
            didSendDuration = false
            self.autoPlay = autoStart
        
            var url : URL

            if(audioType == "network"){
                let urlStr : String = assetPath.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
                if let u = URL(string: urlStr) {
                    url = u
                } else {
                    print("Couldn't parse myURL = \(urlStr)")
                    return
                }

            } else if(audioType == "file"){
                let urlStr : String = assetPath.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
                if let u = URL(string: urlStr) {
                     url = u
                } else {
                    print("Couldn't parse myURL = \(urlStr)")
                    return
                }
            }  else { //asset
                let assetKey = registrar.lookupKey(forAsset: assetPath)

                guard let path = Bundle.main.path(forResource: assetKey, ofType: nil) else {
                     log("resource not found \(assetKey)")
                     result("");
                     return
                }

                url = URL(fileURLWithPath: path)
            }

    //        log("url: "+url.absoluteString)
            do {
                
                /* set session category and mode with options */
                if #available(iOS 10.0, *) {
                    try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playback, mode: AVAudioSession.Mode.default, options: [])
                } else {
                    try AVAudioSession.sharedInstance().setCategory(.playback, options: .mixWithOthers)
                }
                
                try AVAudioSession.sharedInstance().setActive(true)

                let item = AVPlayerItem(url: url)
                self.player = AVPlayer(playerItem: item)
                
                NotificationCenter.default.addObserver(self, selector: #selector(self.playerDidFinishPlaying(note:)), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: item)
                
                 observerStatus = item.observe(\.status, changeHandler: { [weak self] (item, value) in
                     switch item.status {
                     case .unknown:
                         debugPrint("status: unknown")
                     case .readyToPlay:
                         debugPrint("status: ready to play")
                         if(self?.autoPlay == true){
                            self?.play()
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
                
                //self.player?.prepareToPlay()
                
                self.currentTime = 0
                self.playing = false

                if(autoStart){
                    //play()
                }
                //self.setVolume(volume: volume)
                
                result(true);
                //log("play_ok");
                
                //let asset = AVURLAsset(url: url!, options: nil)
                
            } catch let error {
                result(error);
                log(error.localizedDescription)
                print(error.localizedDescription)
            }
        }

    func seek(to: Int){
        
        let targetTime = CMTimeMakeWithSeconds(Double(to), preferredTimescale: 1) // videoLastDuration hold the previous video state.
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
        NotificationCenter.default.removeObserver(self)
    }
    
    func pause(){
        self.player?.pause()
        self.playing = false
        self.currentTimeTimer?.invalidate()
    }
        
    @objc func updateTimer(){
        //log("updateTimer");
        if let p = self.player {
            if let currentItem = p.currentItem {
                if(!didSendDuration && p.status == .readyToPlay){
                    didSendDuration = true
                    let audioDurationSeconds = CMTimeGetSeconds(currentItem.duration) //CMTimeGetSeconds(asset.duration)
                    self.channel.invokeMethod(Music.METHOD_CURRENT, arguments: ["totalDuration": audioDurationSeconds])
                }
                self.currentTime = CMTimeGetSeconds(currentItem.currentTime())
            }
        }
    }
}

class Music : NSObject {
    
    static let METHOD_POSITION = "player.position"
    static let METHOD_FINISHED = "player.finished"
    static let METHOD_IS_PLAYING = "player.isPlaying"
    static let METHOD_CURRENT = "player.current"
    static let METHOD_VOLUME = "player.volume"
    
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

    let channel: FlutterMethodChannel
    let registrar: FlutterPluginRegistrar
    
    init(messenger: FlutterBinaryMessenger, registrar: FlutterPluginRegistrar) {
        self.channel = FlutterMethodChannel(name: "assets_audio_player", binaryMessenger: messenger);
        self.registrar = registrar
    }
    
    func start(){
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
                let autoStart = args["autoStart"] as! Bool
                self.getOrCreatePlayer(id: id)
                    .open(
                        assetPath: assetPath,
                        audioType: audioType,
                        autoStart: autoStart,
                        volume:volume,
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

