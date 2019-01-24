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

  /// Retrieve directly the current song position (in seconds)
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

  /// Change the current position of the song
  /// Tells the player to go to a specific position of the current song
  ///
  ///     AssetsAudioPlayer.seek(Duration(minutes: 1, seconds: 34));
  ///
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

/// The real AssetsAudioPlayer plugin (non-static)
class AssetsAudioPlayerPlugin {
  /// The channel between the native and Dart
  final MethodChannel _channel = const MethodChannel('assets_audio_player');

  /// Then mediaplayer playing state (mutable)
  final BehaviorSubject<bool> _isPlaying =
      BehaviorSubject<bool>(seedValue: false);

  /// Then mediaplayer playing state (immutable)
  ValueObservable<bool> get isPlaying => _isPlaying.stream;

  /// Then mediaplayer playing audio (mutable)
  final BehaviorSubject<PlayingAudio> _current =
      BehaviorSubject<PlayingAudio>();

  /// Then mediaplayer playing audio (immutable)
  ValueObservable<PlayingAudio> get current => _current.stream;

  /// Called when the playing song finished (mutable)
  final BehaviorSubject<bool> _finished =
      BehaviorSubject<bool>(seedValue: false);

  /// Called when the playing song finished (immutable)
  ValueObservable<bool> get finished => _isPlaying.stream;

  /// Then current playing song position (in seconds) (mutable)
  final BehaviorSubject<Duration> _currentPosition =
      BehaviorSubject<Duration>(seedValue: const Duration());

  /// Then current playing song position (in seconds) (immutable)
  Stream<Duration> get currentPosition => _currentPosition.stream;

  /*
      final PublishSubject<bool> _next = PublishSubject<bool>();
      Stream<bool> get next => _next.stream;
    
      final PublishSubject<bool> _prev = PublishSubject<bool>();
      Stream<bool> get prev => _prev.stream;
    */

  /// Stores opened AssetsAudio to use it on the `_current` BehaviorSubject (in `PlayingAudio`)
  AssetsAudio _lastOpenedAssetsAudio;

  /// Call it to dispose stream
  void dispose() {
    _currentPosition.close();
    _isPlaying.close();
    //_next.close();
    //_prev.close();
    _finished.close();
    _current.close();
  }

  /// Private constructor
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
          final totalDuration = _toDuration(call.arguments["totalDuration"]);

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

  /// Open an AssetsAudio
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

  /// Toggle the media player playing state
  void playOrPause() async {
    final bool playing = _isPlaying.value;
    if (playing) {
      pause();
    } else {
      play();
    }
  }

  /// Toggle the media player playing state, set to play
  void play() {
    _channel.invokeMethod('play');
  }

  /// Toggle the media player playing state, set to pause
  void pause() {
    _channel.invokeMethod('pause');
  }

  /// Tells the media player to go to a specific position
  void seek(Duration to) {
    _channel.invokeMethod('seek', to.inSeconds.round());
  }

  /// Stops and release the current mediaplayer
  void stop() {
    _channel.invokeMethod('stop');
  }
}
