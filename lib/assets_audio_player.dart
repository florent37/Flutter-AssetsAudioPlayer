import 'dart:async';

import 'package:flutter/services.dart';
import 'package:rxdart/rxdart.dart';
import 'package:rxdart/subjects.dart';

/// The AssetsAudioPlayer, playing audios from assets/
/// Example :
///
///     AssetsAudioPlayer _assetsAudioPlayer = AssetsAudioPlayer();
///
///     _assetsAudioPlayer.open(AssetsAudio(
///       asset: "",
///       folder: ,
///     )
///
/// Don't forget to declare the audio folder in your `pubspec.yaml`
///
///     flutter:
///       assets:
///         - assets/audios/
///
class AssetsAudioPlayer {
  /// The channel between the native and Dart
  final MethodChannel _channel = const MethodChannel('assets_audio_player');

  /// Then mediaplayer playing state (mutable)
  final BehaviorSubject<bool> _isPlaying = BehaviorSubject<bool>.seeded(false);

  /// Boolean observable representing the current mediaplayer playing state
  ///
  /// retrieve directly the current player state
  ///     final bool playing = _assetsAudioPlayer.isPlaying.value;
  ///
  /// will follow the AssetsAudioPlayer playing state
  ///     return StreamBuilder(
  ///         stream: _assetsAudioPlayer.currentPosition,
  ///         builder: (context, asyncSnapshot) {
  ///             final bool isPlaying = asyncSnapshot.data;
  ///             return Text(isPlaying ? "Pause" : "Play");
  ///         }),
  ValueStream<bool> get isPlaying => _isPlaying.stream;

  /// Then mediaplayer playing audio (mutable)
  final BehaviorSubject<PlayingAudio> _current =
      BehaviorSubject<PlayingAudio>();

  /// The current playing audio, filled with the total song duration
  /// Exposes a PlayingAudio
  ///
  /// Retrieve directly the current played asset
  ///     final PlayingAudio playing = _assetsAudioPlayer.current.value;
  ///
  /// Listen to the current playing song
  ///     _assetsAudioPlayer.current.listen((playingAudio){
  ///         final asset = playingAudio.assetAudio;
  ///         final songDuration = playingAudio.duration;
  ///     })
  ///
  ValueStream<PlayingAudio> get current => _current.stream;

  /// Called when the playing song finished (mutable)
  final BehaviorSubject<bool> _finished = BehaviorSubject<bool>.seeded(false);

  /// Called when the current song has finished to play
  ///     _assetsAudioPlayer.finished.listen((finished){
  ///
  ///     })
  ///
  ValueStream<bool> get finished => _isPlaying.stream;

  /// Then current playing song position (in seconds) (mutable)
  final BehaviorSubject<Duration> _currentPosition =
      BehaviorSubject<Duration>.seeded(const Duration());

  /// Retrieve directly the current song position (in seconds)
  ///     final Duration position = _assetsAudioPlayer.currentPosition.value;
  ///
  ///     return StreamBuilder(
  ///         stream: _assetsAudioPlayer.currentPosition,
  ///         builder: (context, asyncSnapshot) {
  ///             final Duration duration = asyncSnapshot.data;
  ///             return Text(duration.toString());
  ///         }),
  Stream<Duration> get currentPosition => _currentPosition.stream;

  /*
      final PublishSubject<bool> _next = PublishSubject<bool>();
      Stream<bool> get next => _next.stream;
    
      final PublishSubject<bool> _prev = PublishSubject<bool>();
      Stream<bool> get prev => _prev.stream;
    */

  /// Stores opened asset audio path to use it on the `_current` BehaviorSubject (in `PlayingAudio`)
  String _lastOpenedAssetsAudioPath;

  final BehaviorSubject<bool> _loop = BehaviorSubject<bool>.seeded(false);
  ValueStream<bool> get isLooping => _loop.stream;
  bool get loop => _loop.value;
  void set loop(value) { _loop.value = value; }
  void toggleLoop(){
    loop = !loop;
  }

  /// Call it to dispose stream
  void dispose() {
    _currentPosition.close();
    _isPlaying.close();
    //_next.close();
    //_prev.close();
    _finished.close();
    _current.close();
  }

  AssetsAudioPlayer() {
    _channel.setMethodCallHandler((MethodCall call) async {
      //print("received call ${call.method} with arguments ${call.arguments}");
      switch (call.method) {
        case 'log':
          print("log: " + call.arguments);
          break;
        case 'player.finished':
          _onfinished(call.arguments);
          break;
        case 'player.current':
          final totalDuration = _toDuration(call.arguments["totalDuration"]);

          _current.value = PlayingAudio(
            assetAudioPath: _lastOpenedAssetsAudioPath,
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

  void _onfinished(bool isFinished) {
    _finished.value = isFinished;
    if(loop){
      if(_lastOpenedAssetsAudioPath != null) {
        open(_lastOpenedAssetsAudioPath);
      }
    }
  }

  /// Converts a number to duration
  Duration _toDuration(num value) {
    if (value is int) {
      return Duration(seconds: value);
    } else if (value is double) {
      return Duration(seconds: value.round());
    } else {
      return Duration();
    }
  }

  /// Open a song from the asset
  /// ### Example
  ///
  ///     AssetsAudioPlayer _assetsAudioPlayer = AssetsAudioPlayer();
  ///
  ///     _assetsAudioPlayer.open("assets/audios/song1.mp3")
  ///
  /// Don't forget to declare the audio folder in your `pubspec.yaml`
  ///
  ///     flutter:
  ///       assets:
  ///         - assets/audios/
  ///
  void open(String assetAudioPath) async {
    try {
      _channel.invokeMethod('open', assetAudioPath);
    } catch (e) {
      print(e);
    }

    _lastOpenedAssetsAudioPath = assetAudioPath;
  }

  /// Toggle the current playing state
  /// If the media player is playing, then pauses it
  /// If the media player has been paused, then play it
  ///
  ///     _assetsAudioPlayer.playOfPause();
  ///
  void playOrPause() async {
    final bool playing = _isPlaying.value;
    if (playing) {
      pause();
    } else {
      play();
    }
  }

  /// Tells the media player to play the current song
  ///     _assetsAudioPlayer.play();
  ///
  void play() {
    _channel.invokeMethod('play');
  }

  /// Tells the media player to play the current song
  ///     _assetsAudioPlayer.pause();
  ///
  void pause() {
    _channel.invokeMethod('pause');
  }

  /// Change the current position of the song
  /// Tells the player to go to a specific position of the current song
  ///
  ///     _assetsAudioPlayer.seek(Duration(minutes: 1, seconds: 34));
  ///
  void seek(Duration to) {
    _channel.invokeMethod('seek', to.inSeconds.round());
  }

  /// Tells the media player to stop the current song, then release the MediaPlayer
  ///     _assetsAudioPlayer.stop();
  ///
  void stop() {
    _channel.invokeMethod('stop');
  }

}

/// Represents the current played audio asset
/// When the player opened a song, it will ping AssetsAudioPlayer.current with a `AssetsAudio`
///
/// ### Example
///     final assetAudio = AssetsAudio(
///       assets/audios/song1.mp3,
///     )
///
///     _assetsAudioPlayer.current.listen((PlayingAudio current){
///         //ex: retrieve the current song's total duration
///     });
///
///     _assetsAudioPlayer.open(assetAudio);
///
class PlayingAudio {
  ///the opened asset
  final String assetAudioPath;

  ///the current song's total duration
  final Duration duration;

  const PlayingAudio({this.assetAudioPath = "", this.duration = Duration.zero});
}
