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

class Music : NSObject, AVAudioPlayerDelegate {
    
    static let METHOD_POSITION = "player.position"
    static let METHOD_FINISHED = "player.finished"
    static let METHOD_IS_PLAYING = "player.isPlaying"
    static let METHOD_CURRENT = "player.current"

    let channel: FlutterMethodChannel
    let registrar: FlutterPluginRegistrar
    init(messenger: FlutterBinaryMessenger, registrar: FlutterPluginRegistrar) {
        self.channel = FlutterMethodChannel(name: "assets_audio_player", binaryMessenger: messenger);
        self.registrar = registrar
    }
    
    func log(_ message: String){
        channel.invokeMethod("log", arguments: message)
    }
    
    func start(){
        channel.setMethodCallHandler({(call: FlutterMethodCall, result: FlutterResult) -> Void in
            self.log(call.method + call.arguments.debugDescription)
            switch(call.method){
            case "isPlaying" :
                result(self.playing); break;
            case "play" : self.play();result(true); break;
            case "pause" : self.pause();result(true); break;
            case "stop" : self.stop();result(true); break;
            case "seek" : if(call.arguments is Int) {
                let pos = call.arguments as! Int;
                self.seek(to: pos);
                result(true);
            } else {
                result(FlutterError(code: "WRONG_FORMAT",
                                    message: "The specified argument must be an Int.",
                                    details: nil))
            }
            break;
            case "open" :
                if let assetPath = call.arguments as? String {
                    self.open(assetPath: assetPath, result: result);
                } else {
                    result(FlutterError(code: "WRONG_FORMAT",
                                        message: "The specified argument must be a string",
                                        details: nil))
                }
                break;
                
            default:
                result(FlutterMethodNotImplemented);
                break;
                
            }
        })
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
    private var playing : Bool {
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
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool){
        self.channel.invokeMethod(Music.METHOD_FINISHED, arguments: true)
    }
    
    func open(asset: String, folder: String, result: FlutterResult){
        //let assetKey = registrar.lookupKey(forAsset: assetPath)
        //guard let path = Bundle.main.path(forResource: assetKey, ofType: nil) else {
        //    log("resource not found \(assetKey)")
        guard let url = Bundle.main.url(forResource: asset, withExtension: "", subdirectory: "Frameworks/App.framework/flutter_assets/"+folder) else {
            log("resource not found "+asset)
            result("");
            return
        }
        
        let url = URL(fileURLWithPath: path)
//        log("url: "+url.absoluteString)
        do {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback, with: .mixWithOthers)
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
            
            play()
            
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
    
    func pause(){
        self.player?.pause()
        self.playing = false
        self.currentTimeTimer?.invalidate()
    }
    
    func seek(to: Int){
        self.player?.currentTime = Double(to)
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
    
    @objc func updateTimer(){
        //log("updateTimer");
        if let p = self.player {
            self.currentTime = p.currentTime
        }
    }
    
}

