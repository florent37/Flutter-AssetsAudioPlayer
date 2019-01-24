import 'dart:async';

import 'package:flutter/services.dart';
import 'package:rxdart/rxdart.dart';
import 'package:rxdart/subjects.dart';

/// An audio asset, represented by an asset name and a folder
/// This class is used by AssetsAudioPlayer to open a song
/// 
/// ### Example
///
///     AssetsAudioPlayer.open(AssetsAudio(
///       asset: "song1.mp3",
///       folder: "assets/audios/",
///     )
/// 
/// Don't forget to declare the audio folder in your `pubspec.yaml`
/// 
///     flutter:
///       assets:
///         - assets/audios/
///
class AssetsAudio {
  final String asset;
  final String folder;

  const AssetsAudio({this.asset, this.folder});
}

/// Represents the current played audio asset
/// When the player opened a song, it will ping AssetsAudioPlayer.current with a `AssetsAudio`
/// 
/// ### Example
///     final assetAudio = AssetsAudio(
///       asset: "song1.mp3",
///       folder: "assets/audios/",
///     )
/// 
///     AssetsAudioPlayer.current.listen((PlayingAudio current){
///         //ex: retrieve the current song's total duration
///     });
/// 
///     AssetsAudioPlayer.open(assetAudio);
///
class PlayingAudio {
  ///the opened asset
  final AssetsAudio assetAudio;
  ///the current song's total duration
  final Duration duration;

  const PlayingAudio({this.assetAudio = const AssetsAudio(), this.duration});
}

/// The static AssetsAudioPlayer, representing the native Audio Media Player
/// From flutter, you will call this class directly
class AssetsAudioPlayer {

  /// The real AssetsAudioPlayer plugin, which has no static methods
  static AssetsAudioPlayerPlugin _plugin = AssetsAudioPlayerPlugin._();

  /// The current playing audio, filled with the total song duration
  /// Exposes a PlayingAudio
  /// 
  /// Retrieve directly the current played asset
  ///     final PlayingAudio playing = AssetsAudioPlayer.current.value;
  ///
  /// Listen to the current playing song
  ///     AssetsAudioPlayer.current.listen((playingAudio){
  ///         final asset = playingAudio.assetAudio;
  ///         final songDuration = playingAudio.duration;
  ///     })
  /// 
  static ValueObservable<PlayingAudio> get current => _plugin.current;

  /// Boolean observable representing the current mediaplayer playing state
  /// 
  /// retrieve directly the current player state
  ///     final bool playing = AssetsAudioPlayer.isPlaying.value;
  /// 
  /// will follow the AssetsAudioPlayer playing state
  ///     return StreamBuilder(
  ///         stream: AssetsAudioPlayer.currentPosition,
  ///         builder: (context, asyncSnapshot) {
  ///             final bool isPlaying = asyncSnapshot.data;
  ///             return Text(isPlaying ? "Pause" : "Play");  
  ///         }),
  static ValueObservable<bool> get isPlaying => _plugin.isPlaying;

  /// Called when the current song has finished to play
  ///     AssetsAudioPlayer.finished.listen((finished){
  ///    
  ///        })
  /// 
  static ValueObservable<bool> get finished => _plugin.finished;

  /// Retrieve directly the current song position
  ///     final Duration position = AssetsAudioPlayer.currentPosition.value;
  /// 
  ///     return StreamBuilder(
  ///         stream: AssetsAudioPlayer.currentPosition,
  ///         builder: (context, asyncSnapshot) {
  ///             final Duration duration = asyncSnapshot.data;
  ///             return Text(duration.toString());  
  ///         }),
  static ValueObservable<Duration> get currentPosition =>
      _plugin.currentPosition;
  //static Stream<bool> get next => _plugin.next;
  //static Stream<bool> get prev => _plugin.prev;

  /// Open a song from the asset
  /// ### Example
  ///
  ///     AssetsAudioPlayer.open(AssetsAudio(
  ///       asset: "song1.mp3",
  ///       folder: "assets/audios/",
  ///     )
  /// 
  /// Don't forget to declare the audio folder in your `pubspec.yaml`
  /// 
  ///     flutter:
  ///       assets:
  ///         - assets/audios/
  /// 
  static void open(AssetsAudio assetAudio) {
    _plugin.open(assetAudio);
  }

  /// Toggle the current playing state
  /// If the media player is playing, then pauses it
  /// If the media player has been paused, then play it
  /// 
  ///     AssetsAudioPlayer.playOfPause();
  /// 
  static void playOrPause() async {
    _plugin.playOrPause();
  }

  /// Tells the media player to play the current song
  ///     AssetsAudioPlayer.play();
  /// 
  static void play() {
    _plugin.play();
  }

  /// Tells the media player to play the current song
  ///     AssetsAudioPlayer.pause();
  /// 
  static void pause() {
    _plugin.pause();
  }

  static void seek(Duration to) {
    _plugin.seek(to);
  }

  /// Tells the media player to stop the current song, then release the MediaPlayer
  ///     AssetsAudioPlayer.stop();
  /// 
  static void stop() {
    _plugin.stop();
  }
}

class AssetsAudioPlayerPlugin {
  final MethodChannel _channel = const MethodChannel('assets_audio_player');

  final BehaviorSubject<bool> _isPlaying =
      BehaviorSubject<bool>(seedValue: false);
  ValueObservable<bool> get isPlaying => _isPlaying.stream;

  final BehaviorSubject<PlayingAudio> _current =
      BehaviorSubject<PlayingAudio>();
  ValueObservable<PlayingAudio> get current => _current.stream;

  final BehaviorSubject<bool> _finished =
      BehaviorSubject<bool>(seedValue: false);
  ValueObservable<bool> get finished => _isPlaying.stream;

  final BehaviorSubject<Duration> _currentPosition =
      BehaviorSubject<Duration>(seedValue: const Duration());
  Stream<Duration> get currentPosition => _currentPosition.stream;

  /*
      final PublishSubject<bool> _next = PublishSubject<bool>();
      Stream<bool> get next => _next.stream;
    
      final PublishSubject<bool> _prev = PublishSubject<bool>();
      Stream<bool> get prev => _prev.stream;
    */
  AssetsAudio _lastOpenedAssetsAudio;

  void dispose() {
    _currentPosition.close();
    _isPlaying.close();
    //_next.close();
    //_prev.close();
    _finished.close();
    _current.close();
  }

  AssetsAudioPlayerPlugin._() {
    _channel.setMethodCallHandler((MethodCall call) async {
      //print("received call ${call.method} with arguments ${call.arguments}");
      switch (call.method) {
        case 'log':
          print("log: " + call.arguments);
          break;
        case 'player.finished':
          _finished.value = call.arguments;
          break;
        case 'player.current':
          final totalDuration = toDuration(call.arguments["totalDuration"]);

          _current.value = PlayingAudio(
            assetAudio: _lastOpenedAssetsAudio,
            duration: totalDuration,
          );
          break;
        /*
            case 'player.next':
              _next.add(true);
              break;
            case 'player.prev':
              _prev.add(true);
              break;
              */
        case 'player.position':
          if (call.arguments is int) {
            _currentPosition.value = Duration(seconds: call.arguments);
          } else if (call.arguments is double) {
            double value = call.arguments;
            _currentPosition.value = Duration(seconds: value.round());
          }
          break;
        case 'player.isPlaying':
          _isPlaying.value = call.arguments;
          break;
        default:
          print('[ERROR] Channel method ${call.method} not implemented.');
      }
    });
  }

  Duration toDuration(num value) {
    if (value is int) {
      return Duration(seconds: value);
    } else if (value is double) {
      return Duration(seconds: value.round());
    } else {
      return Duration();
    }
  }

  void open(AssetsAudio assetAudio) async {
    String assetName = assetAudio.asset;
    if (assetName.startsWith("/")) {
      assetName = assetName.substring(1);
    }
    String folder = assetAudio.folder;
    if (folder.endsWith("/")) {
      folder = folder.substring(0, folder.length - 1);
    }
    if (folder.startsWith("/")) {
      folder = folder.substring(1);
    }

    try {
      _channel.invokeMethod(
          'open', <String, dynamic>{'file': assetName, 'folder': folder});
    } catch (e) {
      print(e);
    }

    _lastOpenedAssetsAudio = assetAudio;
  }

  void playOrPause() async {
    final bool playing = _isPlaying.value;
    if (playing) {
      pause();
    } else {
      play();
    }
  }

  void play() {
    _channel.invokeMethod('play');
  }

  void pause() {
    _channel.invokeMethod('pause');
  }

  void seek(Duration to) {
    _channel.invokeMethod('seek', to.inSeconds.round());
  }

  void stop() {
    _channel.invokeMethod('stop');
  }
}
