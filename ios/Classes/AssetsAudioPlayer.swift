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
    
    init(channel: FlutterMethodChannel, registrar: FlutterPluginRegistrar) {
        self.channel = channel
        self.registrar = registrar
    }
    
    func log(_ message: String){
        channel.invokeMethod("log", arguments: message)
    }
    
    func open(assetPath: String, autoStart: Bool, result: FlutterResult){
            let assetKey = registrar.lookupKey(forAsset: assetPath)
            guard let path = Bundle.main.path(forResource: assetKey, ofType: nil) else {
                 log("resource not found \(assetKey)")
                 result("");
                 return
            }
            
            let url = URL(fileURLWithPath: path)
    //        log("url: "+url.absoluteString)
            do {
                
                /* set session category and mode with options */
                if #available(iOS 10.0, *) {
                    try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playback, mode: AVAudioSession.Mode.default, options: [])
                } else {
                    try AVAudioSession.sharedInstance().setCategory(.playback, options: .mixWithOthers)
                }
                
                try AVAudioSession.sharedInstance().setActive(true)
                
                /* The following line is required for the player to work on iOS 11. Change the file type accordingly */
                if #available(iOS 11.0, *) {
                    self.player = try AVAudioPlayer(contentsOf: url, fileTypeHint: AVFileType.mp3.rawValue)
                } else {
                    /* iOS 10 and earlier require the following line: */
                    self.player = try AVAudioPlayer(contentsOf: url)
                }
                
                if(self.player == nil){
                    //log("player is null");
                    return
                }
                
                self.player?.prepareToPlay()
                
                self.currentTime = 0
                self.playing = false
                
                self.player?.delegate = self

                if(autoStart){
                    play()
                }
                
                result(true);
                //log("play_ok");
                
                let asset = AVURLAsset(url: url, options: nil)
        
                let audioDurationSeconds = CMTimeGetSeconds(asset.duration)
                
                self.channel.invokeMethod(Music.METHOD_CURRENT, arguments: ["totalDuration": audioDurationSeconds])
                
            } catch let error {
                result(error);
                log(error.localizedDescription)
                print(error.localizedDescription)
            }
        }

    func seek(to: Int){
        self.player?.currentTime = Double(to)
    }
    
    func setVolume(volume: Double){
        self.player?.volume = Float(volume)
        self.channel.invokeMethod(Music.METHOD_VOLUME, arguments: volume)
    }
    
    func stop(){
        self.player?.stop()
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
            _currentTime = newValue
            self.channel.invokeMethod(Music.METHOD_POSITION, arguments: self._currentTime)
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
    var player: AVAudioPlayer?
    
    public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool){
        self.channel.invokeMethod(Music.METHOD_FINISHED, arguments: true)
    }

    
    func pause(){
        self.player?.pause()
        self.playing = false
        self.currentTimeTimer?.invalidate()
    }
    
    @objc func updateTimer(){
        //log("updateTimer");
        if let p = self.player {
            self.currentTime = p.currentTime
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
                let autoStart = args["autoStart"] as! Bool
                self.getOrCreatePlayer(id: id)
                    .open(assetPath: assetPath, autoStart: autoStart, result: result);
            break;
                
            default:
                result(FlutterMethodNotImplemented);
            break;
                
            }
        })
    }
    
}

