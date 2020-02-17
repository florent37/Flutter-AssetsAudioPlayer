import 'dart:async';

import 'package:flutter/cupertino.dart';
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

  /// Stores opened asset audio path to use it on the `_current` BehaviorSubject (in `PlayingAudio`)
  String _lastOpenedAssetsAudioPath;

  //nullable
  _CurrentPlaylist _playlist;

  ReadingPlaylist get playlist {
    if (_playlist == null) {
      return null;
    } else {
      return ReadingPlaylist(
          //immutable copy
          assetAudioPaths: _playlist.playlist.assetAudioPaths,
          currentIndex: _playlist.playlistIndex);
    }
  }

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

  /// The current playing playlist audio, filled with the total song duration
  /// works the same as @current stream
  final BehaviorSubject<PlaylistPlayingAudio> _playlistCurrent =
      BehaviorSubject<PlaylistPlayingAudio>();

  /// The current playlist song
  /// Stream contains null if it has no playlist
  Stream<PlaylistPlayingAudio> get playlistCurrent => _playlistCurrent.stream;

  /// Called when the playing song (or the complete playlist if playing a playlist) finished (mutable)
  final BehaviorSubject<bool> _finished = BehaviorSubject<bool>.seeded(false);

  /// Called when the current song (or the complete playlist) has finished to play
  ///     _assetsAudioPlayer.finished.listen((finished){
  ///
  ///     })
  ///
  ValueStream<bool> get finished => _finished.stream;

  /// Called when the current playlist song has finished (mutable)
  /// Using a playlist, the `finished` stram will be called only if the complete playlist finished
  /// _assetsAudioPlayer.playlistAudioFinished.listen((audio){
  ///      the $audio has finished to play, moving to next audio
  /// })
  final PublishSubject<PlaylistPlayingAudio> _playlistAudioFinished =
      PublishSubject<PlaylistPlayingAudio>();

  /// Called when the current playlist song has finished
  /// Using a playlist, the `finished` stram will be called only if the complete playlist finished
  Stream<PlaylistPlayingAudio> get playlistAudioFinished =>
      _playlistAudioFinished.stream;

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

  final BehaviorSubject<bool> _loop = BehaviorSubject<bool>.seeded(false);

  /// Called when the looping state changes
  ///     _assetsAudioPlayer.isLooping.listen((looping){
  ///
  ///     })
  ///
  ValueStream<bool> get isLooping => _loop.stream;

  /// returns the looping state : true -> looping, false -> not looping
  bool get loop => _loop.value;

  /// assign the looping state : true -> looping, false -> not looping
  set loop(value) {
    _loop.value = value;
  }

  /// toggle the looping state
  /// if it was looping -> stops this
  /// if it was'nt looping -> now it is
  void toggleLoop() {
    loop = !loop;
  }

  /// Call it to dispose stream
  void dispose() {
    _currentPosition.close();
    _isPlaying.close();
    _finished.close();
    _current.close();
    _playlistAudioFinished.close();
    _playlistCurrent.close();
    _loop.close();
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

          final playingAudio = PlayingAudio(
            assetAudioPath: _lastOpenedAssetsAudioPath,
            duration: totalDuration,
          );
          _current.value = playingAudio;
          if (_playlist != null) {
            _playlistCurrent.value = PlaylistPlayingAudio(
                playingAudio: playingAudio,
                index: _playlist.playlistIndex,
                hasNext: _playlist.hasNext(),
                playlist: _playlist.playlist);
          }
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

  void playlistPlayAtIndex(int index) {
    _playlist.moveTo(index);
    _open(_playlist.currentAudioPath(), resetPlaylist: false);
  }

  bool playlistPrevious() {
    if (_playlist != null) {
      if (_playlist.hasPrev()) {
        _playlist.selectPrev();
        _open(_playlist.currentAudioPath(), resetPlaylist: false);
        return true;
      } else if (_playlist.playlistIndex == 0) {
        seek(Duration.zero);
        return true;
      }
    }

    return false;
  }

  bool playlistNext({bool stopIfLast = false}) {
    if (_playlist != null) {
      if (_playlist.hasNext()) {
        _playlistAudioFinished.add(PlaylistPlayingAudio(
          playingAudio: this.current.value,
          index: _playlist.playlistIndex,
          hasNext: true,
          playlist: _playlist.playlist,
        ));
        _playlist.selectNext();
        _open(_playlist.currentAudioPath(), resetPlaylist: false);

        return true;
      } else if (loop) {
        //last element
        _playlistAudioFinished.add(PlaylistPlayingAudio(
          playingAudio: this.current.value,
          index: _playlist.playlistIndex,
          hasNext: false,
          playlist: _playlist.playlist,
        ));

        _playlist.returnToFirst();
        _open(_playlist.currentAudioPath(), resetPlaylist: false);

        return true;
      } else if (stopIfLast) {
        stop();
        return true;
      }
    }
    return false;
  }

  void _onfinished(bool isFinished) {
    if (_playlist != null) {
      bool next = playlistNext(stopIfLast: false);
      if (next) {
        _finished.value = false; //continue playing the playlist
      } else {
        _finished.value = true; // no next elements -> finished
      }
    } else {
      _finished.value = isFinished;
      if (loop) {
        if (_lastOpenedAssetsAudioPath != null) {
          open(_lastOpenedAssetsAudioPath);
        }
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
    _open(assetAudioPath, resetPlaylist: true);
  }

  //private method, used in open(playlist) and open(path)
  void _open(String assetAudioPath, {@required bool resetPlaylist}) async {
    if (resetPlaylist) {
      _playlist = null;
      _playlistAudioFinished.add(null);
    }
    try {
      _channel.invokeMethod('open', assetAudioPath);
    } catch (e) {
      print(e);
    }

    _lastOpenedAssetsAudioPath = assetAudioPath;
  }

  void openPlaylist(Playlist playlist) async {
    if (playlist != null &&
        playlist.assetAudioPaths != null &&
        playlist.assetAudioPaths.length > 0) {
      this._playlist = _CurrentPlaylist(playlist: playlist);
      _playlist.moveTo(playlist.startIndex);
      _open(_playlist.currentAudioPath(), resetPlaylist: false);
    } else {
      //do nothing
      //throw exception ?
    }
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

  /// TODO ShufflePlaylist
  //void shufflePlaylist() {
  //  TODO()
  //}

  /// TODO Playlist Loop / Loop 1
  //void playlistLoop(PlaylistLoop /* enum */ mode) {
  //  TODO()
  //}
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
@immutable
class PlayingAudio {
  ///the opened asset
  final String assetAudioPath;

  ///the current song's total duration
  final Duration duration;

  const PlayingAudio({this.assetAudioPath = "", this.duration = Duration.zero});
}

@immutable
class Playlist {
  final List<String> assetAudioPaths;

  final int startIndex;

  const Playlist({@required this.assetAudioPaths, this.startIndex = 0});
}

@immutable
class ReadingPlaylist {
  final List<String> assetAudioPaths;
  final int currentIndex;

  const ReadingPlaylist(
      {@required this.assetAudioPaths, this.currentIndex = 0});
}

class _CurrentPlaylist {
  final Playlist playlist;

  int playlistIndex = 0;

  int selectNext() {
    playlistIndex += 1;
    return playlistIndex;
  }

  int moveTo(int index) {
    if (index < 0) {
      playlistIndex = 0;
    } else {
      playlistIndex = index % playlist.assetAudioPaths.length;
    }
    return playlistIndex;
  }

  String audioPath({int at}) {
    return playlist.assetAudioPaths[at];
  }

  String currentAudioPath() {
    return audioPath(at: playlistIndex);
  }

  bool hasNext() {
    return playlistIndex + 1 <= playlist.assetAudioPaths.length;
  }

  _CurrentPlaylist({@required this.playlist});

  void returnToFirst() {
    playlistIndex = 0;
  }

  bool hasPrev() {
    return playlistIndex > 0;
  }

  void selectPrev() {
    playlistIndex--;
    if (playlistIndex < 0) {
      playlistIndex = 0;
    }
  }
}

@immutable
class PlaylistPlayingAudio {
  ///the opened asset
  final PlayingAudio playingAudio;

  /// this audio index in playlist
  final int index;

  /// if this audio has a next element (if no : last element)
  final bool hasNext;

  /// the parent playlist
  final Playlist playlist;

  PlaylistPlayingAudio(
      {@required this.playingAudio,
      @required this.index,
      @required this.hasNext,
      @required this.playlist});
}
