import 'dart:async';

import 'package:assets_audio_player/playing.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:rxdart/rxdart.dart';
import 'package:rxdart/subjects.dart';
import 'package:uuid/uuid.dart';

import 'playing.dart';
export 'playing.dart';

import 'playable.dart';
export 'playable.dart';

const _DEFAULT_AUTO_START = true;
const _DEFAULT_PLAYER = "DEFAULT_PLAYER";

const METHOD_POSITION = "player.position";
const METHOD_VOLUME = "player.volume";
const METHOD_FINISHED = "player.finished";
const METHOD_IS_PLAYING = "player.isPlaying";
const METHOD_CURRENT = "player.current";
//const _METHOD_NEXT = "player.next"
//const _METHOD_PREV = "player.prev"

/// The AssetsAudioPlayer, playing audios from assets/
/// Example :
///
///     AssetsAudioPlayer _assetsAudioPlayer = AssetsAudioPlayer();
///
///     _assetsAudioPlayer.open(Audio(
///         "/assets/audio/myAudio.mp3",
///     ))
///
/// Don't forget to declare the audio folder in your `pubspec.yaml`
///
///     flutter:
///       assets:
///         - assets/audios/
class AssetsAudioPlayer {
  static final double minVolume = 0.0;
  static final double maxVolume = 1.0;
  static final double defaultVolume = maxVolume;

  static final uuid = Uuid();

  /// The channel between the native and Dart
  final MethodChannel _sendChannel = const MethodChannel('assets_audio_player');
  MethodChannel _recieveChannel;

  /// Stores opened asset audio path to use it on the `_current` BehaviorSubject (in `PlayingAudio`)
  String _lastOpenedAssetsAudioPath;

  _CurrentPlaylist _playlist;

  final String id;

  AssetsAudioPlayer._({this.id = _DEFAULT_PLAYER}) {
    _init();
  }

  static final Map<String, AssetsAudioPlayer> _players = Map();

  static AssetsAudioPlayer _getOrCreate({String id}) {
    if (_players.containsKey(id)) {
      return _players[id];
    } else {
      final player = AssetsAudioPlayer._(id: id);
      _players[id] = player;
      return player;
    }
  }

  factory AssetsAudioPlayer.newPlayer() => _getOrCreate(id: uuid.v4());

  factory AssetsAudioPlayer({String id = _DEFAULT_PLAYER}) =>
      _getOrCreate(id: id);

  ReadingPlaylist get playlist {
    if (_playlist == null) {
      return null;
    } else {
      return ReadingPlaylist(
        //immutable copy
        audios: _playlist.playlist.audios,
        currentIndex: _playlist.playlistIndex,
      );
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
  final BehaviorSubject<Playing> _current = BehaviorSubject();

  /// The current playing audio, filled with the total song duration
  /// Exposes a PlayingAudio
  ///
  /// Retrieve directly the current played asset
  ///     final PlayingAudio playing = _assetsAudioPlayer.current.value;
  ///
  /// Listen to the current playing song
  ///     _assetsAudioPlayer.current.listen((playing){
  ///         final path = playing.audio.path;
  ///         final songDuration = playing.audio.duration;
  ///     })
  ///
  ValueStream<Playing> get current => _current.stream;

  /// Called when the the complete playlist finished to play (mutable)
  final BehaviorSubject<bool> _playlistFinished =
      BehaviorSubject<bool>.seeded(false);

  /// Called when the complete playlist has finished to play
  ///     _assetsAudioPlayer.finished.listen((finished){
  ///
  ///     })
  ///
  ValueStream<bool> get playlistFinished => _playlistFinished.stream;

  /// Called when the current playlist song has finished (mutable)
  /// Using a playlist, the `finished` stram will be called only if the complete playlist finished
  /// _assetsAudioPlayer.playlistAudioFinished.listen((audio){
  ///      the $audio has finished to play, moving to next audio
  /// })
  final PublishSubject<Playing> _playlistAudioFinished = PublishSubject();

  /// Called when the current playlist song has finished
  /// Using a playlist, the `finished` stram will be called only if the complete playlist finished
  Stream<Playing> get playlistAudioFinished => _playlistAudioFinished.stream;

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

  /// The volume of the media Player (min: 0, max: 1)
  final BehaviorSubject<double> _volume =
      BehaviorSubject<double>.seeded(defaultVolume);

  /// Streams the volume of the media Player (min: 0, max: 1)
  ///     final double volume = _assetsAudioPlayer.volume.value;
  ///
  ///     return StreamBuilder(
  ///         stream: _assetsAudioPlayer.volume,
  ///         builder: (context, asyncSnapshot) {
  ///             final double volume = asyncSnapshot.data;
  ///             return Text("volume: ${volume.toString()});
  ///         }),
  ValueStream<double> get volume => _volume.stream;

  final BehaviorSubject<bool> _loop = BehaviorSubject<bool>.seeded(false);

  /// Called when the looping state changes
  ///     _assetsAudioPlayer.isLooping.listen((looping){
  ///
  ///     })
  ///
  ValueStream<bool> get isLooping => _loop.stream;

  final BehaviorSubject<RealtimePlayingInfos> _realtimePlayingInfos = BehaviorSubject<RealtimePlayingInfos>();
  ValueStream<RealtimePlayingInfos> get realtimePlayingInfos => _realtimePlayingInfos.stream;


  Duration _lastSeek;

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
    stop();

    _currentPosition.close();
    _isPlaying.close();
    _volume.close();
    _playlistFinished.close();
    _current.close();
    _playlistAudioFinished.close();
    _loop.close();
    _realtimePlayingInfos.close();
    _realTimeSubscription?.cancel();

    _players.remove(this.id);
  }

  _init() {
    _recieveChannel = MethodChannel('assets_audio_player/$id');
    _recieveChannel.setMethodCallHandler((MethodCall call) async {
      //print("received call ${call.method} with arguments ${call.arguments}");
      switch (call.method) {
        case 'log':
          print("log: " + call.arguments);
          break;
        case METHOD_FINISHED:
          _onfinished(call.arguments);
          break;
        case METHOD_CURRENT:
          final totalDuration = _toDuration(call.arguments["totalDuration"]);

          final playingAudio = PlayingAudio(
            assetAudioPath: _lastOpenedAssetsAudioPath,
            duration: totalDuration,
          );

          if (_playlist != null) {
            _current.value = Playing(
              audio: playingAudio,
              index: _playlist.playlistIndex,
              hasNext: _playlist.hasNext(),
              playlist: ReadingPlaylist(
                  audios: _playlist.playlist.audios,
                  currentIndex: _playlist.playlistIndex),
            );
          }
          break;
        case METHOD_POSITION:
          if (call.arguments is int) {
            _currentPosition.value = Duration(seconds: call.arguments);
          } else if (call.arguments is double) {
            double value = call.arguments;
            _currentPosition.value = Duration(seconds: value.round());
          }
          break;
        case METHOD_IS_PLAYING:
          _isPlaying.value = call.arguments;
          break;
        case METHOD_VOLUME:
          _volume.value = call.arguments;
          break;
        default:
          print('[ERROR] Channel method ${call.method} not implemented.');
      }
    });
  }

  StreamSubscription _realTimeSubscription;
  void _replaceRealtimeSubscription(){
    _realTimeSubscription?.cancel();
    _realTimeSubscription = null;
    _realTimeSubscription = CombineLatestStream.list<dynamic>([
      this.volume,
      this.isPlaying,
      this.isLooping,
      this.current,
      this.currentPosition,
    ]).map((values) =>
      RealtimePlayingInfos(
        volume: values[0],
        isPlaying: values[1],
        isLooping: values[2],
        current: values[3],
        currentPosition: values[4],
        playerId: this.id
      )
    ).listen((readingInfos) {
      this._realtimePlayingInfos.value = readingInfos;
    });
  }

  void playlistPlayAtIndex(int index) {
    _playlist.moveTo(index);
    _open(_playlist.currentAudioPath());
  }

  bool previous() {
    if (_playlist != null) {
      if (_playlist.hasPrev()) {
        _playlist.selectPrev();
        _open(_playlist.currentAudioPath());
        return true;
      } else if (_playlist.playlistIndex == 0) {
        seek(Duration.zero);
        return true;
      }
    }

    return false;
  }

  bool next({bool stopIfLast = false}) {
    if (_playlist != null) {
      if (_playlist.hasNext()) {
        _playlistAudioFinished.add(Playing(
          audio: this._current.value.audio,
          index: this._current.value.index,
          hasNext: true,
          playlist: this._current.value.playlist,
        ));
        _playlist.selectNext();
        _open(_playlist.currentAudioPath());

        return true;
      } else if (loop) {
        //last element
        _playlistAudioFinished.add(Playing(
          audio: this._current.value.audio,
          index: this._current.value.index,
          hasNext: false,
          playlist: this._current.value.playlist,
        ));

        _playlist.returnToFirst();
        _open(_playlist.currentAudioPath());

        return true;
      } else if (stopIfLast) {
        stop();
        return true;
      }
    }
    return false;
  }

  void _onfinished(bool isFinished) {
    bool nextDone = next(stopIfLast: false);
    if (nextDone) {
      _playlistFinished.value = false; //continue playing the playlist
    } else {
      _playlistFinished.value = true; // no next elements -> finished
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

  //private method, used in open(playlist) and open(path)
  void _open(
    String assetAudioPath, {
    bool autoStart = _DEFAULT_AUTO_START,
    double forcedVolume,
  }) async {
    if (assetAudioPath != null) {
      try {
        _sendChannel.invokeMethod('open', {
          "id": this.id,
          "path": assetAudioPath,
          "autoStart": autoStart,
          "volume": forcedVolume ?? this.volume.value ?? defaultVolume,
        });
      } catch (e) {
        print(e);
      }

      _lastOpenedAssetsAudioPath = assetAudioPath;
    }
  }

  void _openPlaylist(
    Playlist playlist, {
    bool autoStart = _DEFAULT_AUTO_START,
    double volume,
  }) async {
    _lastSeek = null;
    _replaceRealtimeSubscription();
    this._playlist = _CurrentPlaylist(playlist: playlist);
    _playlist.moveTo(playlist.startIndex);
    _open(_playlist.currentAudioPath(),
        autoStart: autoStart, forcedVolume: volume);
  }

  /// Open a song from the asset
  /// ### Example
  ///
  ///     AssetsAudioPlayer _assetsAudioPlayer = AssetsAudioPlayer();
  ///
  ///     _assetsAudioPlayer.open(Audio("assets/audios/song1.mp3"))
  ///
  /// Don't forget to declare the audio folder in your `pubspec.yaml`
  ///
  ///     flutter:
  ///       assets:
  ///         - assets/audios/
  ///
  void open(Playable playable,
      {bool autoStart = _DEFAULT_AUTO_START, double volume}) async {
    if (playable is Playlist &&
        playable.audios != null &&
        playable.audios.length > 0) {
      _openPlaylist(playable, autoStart: autoStart, volume: volume);
    } else if (playable is Audio) {
      _openPlaylist(Playlist(audios: [playable]),
          autoStart: autoStart, volume: volume);
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
    _sendChannel.invokeMethod('play', {
      "id": this.id,
    });
  }

  /// Tells the media player to play the current song
  ///     _assetsAudioPlayer.pause();
  ///
  void pause() {
    _sendChannel.invokeMethod('pause', {
      "id": this.id,
    });
  }

  /// Change the current position of the song
  /// Tells the player to go to a specific position of the current song
  ///
  ///     _assetsAudioPlayer.seek(Duration(minutes: 1, seconds: 34));
  ///
  void seek(Duration to) {
    if(to != _lastSeek) {
      _lastSeek = to;
      print("to: $to");
      _sendChannel.invokeMethod('seek', {
        "id": this.id,
        "to": to.inSeconds.round(),
      });
    }
  }

  /// Change the current volume of the MediaPlayer
  ///
  ///     _assetsAudioPlayer.setVolume(0.4);
  ///
  /// MIN : 0
  /// MAX : 1
  ///
  void setVolume(double volume) {
    _sendChannel.invokeMethod('volume',
        {"id": this.id, "volume": volume.clamp(minVolume, maxVolume)});
  }

  /// Tells the media player to stop the current song, then release the MediaPlayer
  ///     _assetsAudioPlayer.stop();
  ///
  void stop() {
    _sendChannel.invokeMethod('stop', {"id": this.id});
  }

//void shufflePlaylist() {
//  TODO()
//}

  /// TODO Playlist Loop / Loop 1
//void playlistLoop(PlaylistLoop /* enum */ mode) {
//  TODO()
//}
}

class _CurrentPlaylist {
  final Playlist playlist;

  int playlistIndex = 0;

  int selectNext() {
    if (hasNext()) {
      playlistIndex += 1;
    }
    return playlistIndex;
  }

  int moveTo(int index) {
    if (index < 0) {
      playlistIndex = 0;
    } else {
      playlistIndex = index % playlist.numberOfItems;
    }
    return playlistIndex;
  }

  //nullable
  String audioPath({int at}) {
    if (at < playlist.audios.length) {
      return playlist.audios[at]?.path;
    } else {
      return null;
    }
  }

  String currentAudioPath() {
    return audioPath(at: playlistIndex);
  }

  bool hasNext() {
    return playlistIndex + 1 < playlist.numberOfItems;
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
