import 'dart:async';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:rxdart/rxdart.dart';
import 'package:rxdart/subjects.dart';
import 'package:uuid/uuid.dart';

import 'playable.dart';
import 'playing.dart';

export 'playable.dart';
export 'playing.dart';

const _DEFAULT_AUTO_START = true;
const _DEFAULT_RESPECT_SILENT_MODE = false;
const _DEFAULT_SHOW_NOTIFICATION = false;
const _DEFAULT_PLAYER = "DEFAULT_PLAYER";

const METHOD_POSITION = "player.position";
const METHOD_VOLUME = "player.volume";
const METHOD_FINISHED = "player.finished";
const METHOD_IS_PLAYING = "player.isPlaying";
const METHOD_IS_BUFFERING = "player.isBuffering";
const METHOD_CURRENT = "player.current";
const METHOD_FORWARD_REWIND_SPEED = "player.forwardRewind";
const METHOD_NEXT = "player.next";
const METHOD_PREV = "player.prev";
const METHOD_PLAY_OR_PAUSE = "player.playOrPause";
const METHOD_PLAY_SPEED = "player.playSpeed";

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
  static final double minPlaySpeed = 0.0;
  static final double maxPlaySpeed = 16.0;
  static final double defaultVolume = maxVolume;
  static final double defaultPlaySpeed = 1.0;

  static final uuid = Uuid();

  /// The channel between the native and Dart
  final MethodChannel _sendChannel = const MethodChannel('assets_audio_player');
  MethodChannel _recieveChannel;

  /// Stores opened asset audio path to use it on the `_current` BehaviorSubject (in `PlayingAudio`)
  Audio _lastOpenedAssetsAudio;

  _CurrentPlaylist _playlist;

  final String id;

  AssetsAudioPlayer._({this.id = _DEFAULT_PLAYER}) {
    _init();
  }

  static final Map<String, AssetsAudioPlayer> _players = Map();

  static Map<String, AssetsAudioPlayer> allPlayers() {
    return Map.from(_players); //return a copy
  }

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

  /// empty constructor now create a new player
  factory AssetsAudioPlayer() => AssetsAudioPlayer.newPlayer();

  factory AssetsAudioPlayer.withId(String id) =>
      _getOrCreate(id: id ?? uuid.v4());

  /// Create a new player for this audio, play it, and dispose it automatically
  static void playAndForget(
    Audio audio, {
    double volume,
    bool respectSilentMode = _DEFAULT_RESPECT_SILENT_MODE,
    Duration seek,
    double playSpeed,
  }) {
    final player = AssetsAudioPlayer.newPlayer();
    StreamSubscription onFinished;
    onFinished = player.playlistFinished.listen((finished) {
      if (finished) {
        onFinished?.cancel();
        player.dispose();
      }
    });
    player.open(
      audio,
      volume: volume,
      seek: seek,
      respectSilentMode: respectSilentMode,
      autoStart: true,
      playSpeed: playSpeed,
    );
  }

  ReadingPlaylist get readingPlaylist {
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

  Playlist get playlist => _playlist?.playlist;

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

  Stream<PlayingAudio> get onReadyToPlay =>
      current.map((playing) => playing?.audio); //another comprehensible name

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
  ValueStream<Duration> get currentPosition => _currentPosition.stream;

  /// The volume of the media Player (min: 0, max: 1)
  final BehaviorSubject<double> _volume =
      BehaviorSubject<double>.seeded(defaultVolume);

  ValueStream<bool> get isBuffering => _isBuffering.stream;
  final BehaviorSubject<bool> _isBuffering =
      BehaviorSubject<bool>.seeded(false);

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
  final BehaviorSubject<bool> _shuffle = BehaviorSubject<bool>.seeded(false);

  /// Called when the looping state changes
  ///     _assetsAudioPlayer.isLooping.listen((looping){
  ///
  ///     })
  ///
  ValueStream<bool> get isLooping => _loop.stream;
  ValueStream<bool> get isShuffling => _shuffle.stream;

  final BehaviorSubject<RealtimePlayingInfos> _realtimePlayingInfos =
      BehaviorSubject<RealtimePlayingInfos>();

  ValueStream<RealtimePlayingInfos> get realtimePlayingInfos =>
      _realtimePlayingInfos.stream;

  BehaviorSubject<double> _playSpeed = BehaviorSubject.seeded(1.0);

  ValueStream<double> get playSpeed => _playSpeed.stream;

  BehaviorSubject<double> _forwardRewindSpeed = BehaviorSubject.seeded(0);

  ValueStream<double> get forwardRewindSpeed => _forwardRewindSpeed.stream;

  Duration _lastSeek;

  /// returns the looping state : true -> looping, false -> not looping
  bool get loop => _loop.value;
  bool get shuffle => _loop.value;

  bool _respectSilentMode = _DEFAULT_RESPECT_SILENT_MODE;

  bool get respectSilentMode => _respectSilentMode;

  /// assign the looping state : true -> looping, false -> not looping
  set loop(value) {
    _loop.value = value;
  }

  set shuffle(value) {
    _shuffle.value = value;
  }

  /// toggle the looping state
  /// if it was looping -> stops this
  /// if it was'nt looping -> now it is
  void toggleLoop() {
    loop = !loop;
  }

  void toggleShuffle() {
    shuffle = !shuffle;
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
    _shuffle.close();
    _playSpeed.close();
    _isBuffering.close();
    _forwardRewindSpeed.close();
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
          _onFinished(call.arguments);
          break;
        case METHOD_NEXT:
          next();
          break;
        case METHOD_PREV:
          previous();
          break;
        case METHOD_PLAY_OR_PAUSE: //eg: from notification
          playOrPause();
          break;
        case METHOD_CURRENT:
          if (call.arguments == null) {
            _current.value = null;
          } else {
            final totalDuration = _toDuration(call.arguments["totalDuration"]);

            final playingAudio = PlayingAudio(
              audio: _lastOpenedAssetsAudio,
              duration: totalDuration,
            );

            if (_playlist != null) {
              final current = Playing(
                audio: playingAudio,
                index: _playlist.playlistIndex,
                hasNext: _playlist.hasNext(),
                playlist: ReadingPlaylist(
                    audios: _playlist.playlist.audios,
                    currentIndex: _playlist.playlistIndex),
              );
              _current.value = current;
            }
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
        case METHOD_IS_BUFFERING:
          _isBuffering.value = call.arguments;
          break;
        case METHOD_PLAY_SPEED:
          _playSpeed.value = call.arguments;
          break;
        case METHOD_FORWARD_REWIND_SPEED:
          final double newValue = call.arguments;
          if (_forwardRewindSpeed.value != newValue) {
            _forwardRewindSpeed.value = newValue;
          }
          break;
        default:
          print('[ERROR] Channel method ${call.method} not implemented.');
      }
    });
  }

  StreamSubscription _realTimeSubscription;

  void _replaceRealtimeSubscription() {
    _realTimeSubscription?.cancel();
    _realTimeSubscription = null;
    _realTimeSubscription = CombineLatestStream.list<dynamic>([
      this.volume,
      this.isPlaying,
      this.isLooping,
      this.isShuffling,
      this.current,
      this.currentPosition,
    ])
        .map((values) => RealtimePlayingInfos(
              volume: values[0],
              isPlaying: values[1],
              isLooping: values[2],
              isShuffling: values[3],
              current: values[4],
              currentPosition: values[5],
              playerId: this.id,
            ))
        .listen((readingInfos) {
      this._realtimePlayingInfos.value = readingInfos;
    });
  }

  Future<void> playlistPlayAtIndex(int index) async {
    _playlist.moveTo(index);
    await _openPlaylistCurrent();
  }

  Future<bool> previous() async {
    if (_playlist != null) {
      if (_playlist.hasPrev()) {
        _playlist.selectPrev();
        await _openPlaylistCurrent();
        return true;
      } else if (_playlist.playlistIndex == 0) {
        seek(Duration.zero);
        return true;
      }
    }

    return false;
  }

  Future<void> _openPlaylistCurrent() async {
    if (_playlist != null) {
      return _open(
        _playlist.currentAudio(),
        forcedVolume: _playlist.volume,
        respectSilentMode: _playlist.respectSilentMode,
        showNotification: _playlist.showNotification,
        playSpeed: _playlist.playSpeed,
      );
    }
  }

  Future<bool> next({bool stopIfLast = false, bool shuffle = false}) {
    return _next(
      stopIfLast: stopIfLast,
      requestByUser: true,
    );
  }

  Future<bool> _next(
      {bool stopIfLast = false, bool requestByUser = false}) async {
    if (_playlist != null) {
      if (shuffle) {
        if (this._current.value != null) {
          _playlistAudioFinished.add(Playing(
            audio: this._current.value.audio,
            index: this._current.value.index,
            hasNext: true,
            playlist: this._current.value.playlist,
          ));
        }
        _playlist.shuffle();
        await _openPlaylistCurrent();
        return true;
      }

      if (_playlist.hasNext()) {
        if (this._current.value != null) {
          _playlistAudioFinished.add(Playing(
            audio: this._current.value.audio,
            index: this._current.value.index,
            hasNext: true,
            playlist: this._current.value.playlist,
          ));
        }
        _playlist.selectNext();
        await _openPlaylistCurrent();

        return true;
      } else if (loop) {
        //last element
        if (this._current.value != null) {
          _playlistAudioFinished.add(Playing(
            audio: this._current.value.audio,
            index: this._current.value.index,
            hasNext: false,
            playlist: this._current.value.playlist,
          ));
        }

        _playlist.returnToFirst();
        await _openPlaylistCurrent();

        return true;
      } else if (stopIfLast) {
        stop();
        return true;
      } else if (requestByUser) {
        //last element
        if (this._current.value != null) {
          _playlistAudioFinished.add(Playing(
            audio: this._current.value.audio,
            index: this._current.value.index,
            hasNext: false,
            playlist: this._current.value.playlist,
          ));
        }

        _playlist.returnToFirst();
        await _openPlaylistCurrent();

        return true;
      }
    }
    return false;
  }

  Future<void> _onFinished(bool isFinished) async {
    bool nextDone = await _next(stopIfLast: false, requestByUser: false);
    if (nextDone) {
      _playlistFinished.value = false; //continue playing the playlist
    } else {
      _playlistFinished.value = true; // no next elements -> finished
    }
  }

  /// Converts a number to duration
  Duration _toDuration(num value) {
    if (value.isNaN) {
      return Duration(seconds: 0);
    } else if (value is int) {
      return Duration(seconds: value);
    } else if (value is double) {
      return Duration(seconds: value.round());
    } else {
      return Duration();
    }
  }

  //private method, used in open(playlist) and open(path)
  Future<void> _open(
    Audio audio, {
    bool autoStart = _DEFAULT_AUTO_START,
    double forcedVolume,
    bool respectSilentMode = _DEFAULT_RESPECT_SILENT_MODE,
    bool showNotification = _DEFAULT_SHOW_NOTIFICATION,
    Duration seek,
    double playSpeed,
  }) async {
    final currentAudio = _lastOpenedAssetsAudio;
    if (audio != null) {
      _respectSilentMode = respectSilentMode;
      try {
        Map<String, dynamic> params = {
          "id": this.id,
          "audioType": audio.audioType.description(),
          "path": audio.path,
          "autoStart": autoStart,
          "respectSilentMode": respectSilentMode,
          "displayNotification": showNotification,
          "volume": forcedVolume ?? this.volume.value ?? defaultVolume,
          "playSpeed": playSpeed ?? this.playSpeed.value ?? defaultPlaySpeed,
        };
        if (seek != null) {
          params["seek"] = seek.inSeconds.round();
        }
        if (audio.package != null) {
          params["package"] = audio.package;
        }
        if (audio.metas != null) {
          if (audio.metas.title != null)
            params["song.title"] = audio.metas.title;
          if (audio.metas.artist != null)
            params["song.artist"] = audio.metas.artist;
          if (audio.metas.album != null)
            params["song.album"] = audio.metas.album;
          if (audio.metas.image != null) {
            params["song.image"] = audio.metas.image.path;
            params["song.imageType"] = audio.metas.image.type.description();
            if (audio.metas.image.package != null)
              params["song.imagePackage"] = audio.metas.image.package;
          }
        }
        _lastOpenedAssetsAudio = audio;
        /*final result = */
        await _sendChannel.invokeMethod('open', params);

        _playlistFinished.value = false;
      } catch (e) {
        _lastOpenedAssetsAudio = currentAudio; //revert to the previous audio
        print(e);
        return Future.error(e);
      }
    }
  }

  Future<void> _openPlaylist(
    Playlist playlist, {
    bool autoStart = _DEFAULT_AUTO_START,
    double volume,
    bool respectSilentMode = _DEFAULT_RESPECT_SILENT_MODE,
    bool showNotification = _DEFAULT_SHOW_NOTIFICATION,
    Duration seek,
    double playSpeed,
  }) async {
    _lastSeek = null;
    _replaceRealtimeSubscription();
    this._playlist = _CurrentPlaylist(
      playlist: playlist,
      volume: volume,
      respectSilentMode: respectSilentMode,
      showNotification: showNotification,
      playSpeed: playSpeed,
    );
    _playlist.moveTo(playlist.startIndex);
    return _open(
      _playlist.currentAudio(),
      autoStart: autoStart,
      forcedVolume: volume,
      playSpeed: playSpeed,
      respectSilentMode: respectSilentMode,
      showNotification: showNotification,
      seek: seek,
    );
  }

  bool get _isLiveStream {
    return _lastOpenedAssetsAudio?.audioType == AudioType.liveStream;
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
  Future<void> open(
    Playable playable, {
    bool autoStart = _DEFAULT_AUTO_START,
    double volume,
    bool respectSilentMode = _DEFAULT_RESPECT_SILENT_MODE,
    bool showNotification = _DEFAULT_SHOW_NOTIFICATION,
    Duration seek,
    double playSpeed,
  }) async {
    if (playable is Playlist &&
        playable.audios != null &&
        playable.audios.length > 0) {
      await _openPlaylist(
        playable,
        autoStart: autoStart,
        volume: volume,
        respectSilentMode: respectSilentMode,
        showNotification: showNotification,
        seek: seek,
        playSpeed: playSpeed,
      );
    } else if (playable is Audio) {
      await _openPlaylist(
        Playlist(audios: [playable]),
        autoStart: autoStart,
        volume: volume,
        respectSilentMode: respectSilentMode,
        showNotification: showNotification,
        seek: seek,
        playSpeed: playSpeed,
      );
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
  Future<void> playOrPause() async {
    final bool playing = _isPlaying.value;
    if (playing) {
      await pause();
    } else {
      await play();
    }
  }

  /// Tells the media player to play the current song
  ///     _assetsAudioPlayer.play();
  ///
  Future<void> play() async {
    if (_isLiveStream) {
      //on livestream, it re-open the media to be live and not on buffer
      await _openPlaylistCurrent();
    } else if (_playlistFinished.value == true) {
      //open the last
      await _openPlaylistCurrent();
    } else {
      await _play();
    }
  }

  Future<void> _play() async {
    await _sendChannel.invokeMethod('play', {
      "id": this.id,
    });
  }

  /// Tells the media player to play the current song
  ///     _assetsAudioPlayer.pause();
  ///
  Future<void> pause() async {
    if (_isLiveStream) {
      //on livestream, we stop
      await stop();
    } else {
      await _sendChannel.invokeMethod('pause', {
        "id": this.id,
      });
    }
  }

  /// Change the current position of the song
  /// Tells the player to go to a specific position of the current song
  ///
  ///     _assetsAudioPlayer.seek(Duration(minutes: 1, seconds: 34));
  ///
  Future<void> seek(Duration to) async {
    if (to != _lastSeek) {
      _lastSeek = to;
      await _sendChannel.invokeMethod('seek', {
        "id": this.id,
        "to": to.inSeconds.round(),
      });
    }
  }

  bool _wasPlayingBeforeForwardRewind;

  /// If positive, forward (progressively)
  /// If Negative rewind (progressively)
  /// If 0 or null, restore the playing state
  Future<void> forwardOrRewind(double speed) async {
    if (speed == 0 || speed == null) {
      if (_wasPlayingBeforeForwardRewind) {
        await play();
      } else {
        await pause();
      }
      _wasPlayingBeforeForwardRewind = null;
    } else {
      if (_wasPlayingBeforeForwardRewind == null) {
        _wasPlayingBeforeForwardRewind = this.isPlaying.value;
      }
      await _sendChannel.invokeMethod('forwardRewind', {
        "id": this.id,
        "speed": speed,
      });
    }
  }

  /// if by > 0 Forward (jump) the current audio, to currentPosition + `by` (duration)
  ///
  /// eg: _assetsAudioPlayer.foward(Duration(seconds: 10))
  ///
  /// Rewind (jump) the current audio, to currentPosition - `by` (duration)
  ///
  ///  eg: _assetsAudioPlayer.rewind(Duration(seconds: 10))
  ///
  Future<void> seekBy(Duration by) async {
    //only if playing a song
    final playing = this.current.value;
    if (playing != null) {
      final totalDuration = playing.audio.duration;

      final currentPosition = this.currentPosition.value ?? Duration();

      if (by.inMilliseconds >= 0) {
        final nextPosition = currentPosition + by;

        //don't seek more that song duration
        final currentPositionCapped = Duration(
          milliseconds:
              min(totalDuration.inMilliseconds, nextPosition.inMilliseconds),
        );

        await seek(currentPositionCapped);
      } else {
        //only if playing a song
        final currentPosition = this.currentPosition.value ?? Duration();
        final nextPosition = currentPosition + by;

        //don't seek less that 0
        final currentPositionCapped = Duration(
          milliseconds: max(0, nextPosition.inMilliseconds),
        );

        await seek(currentPositionCapped);
      }
    }
  }

  /// Change the current volume of the MediaPlayer
  ///
  ///     _assetsAudioPlayer.setVolume(0.4);
  ///
  /// MIN : 0
  /// MAX : 1
  ///
  Future<void> setVolume(double volume) async {
    await _sendChannel.invokeMethod('volume', {
      "id": this.id,
      "volume": volume.clamp(minVolume, maxVolume),
    });
  }

  /// Tells the media player to stop the current song, then release the MediaPlayer
  ///     _assetsAudioPlayer.stop();
  ///
  Future<void> stop() async {
    await _sendChannel.invokeMethod('stop', {
      "id": this.id,
    });
  }

  /// Change the current play speed (rate) of the MediaPlayer
  ///
  ///     _assetsAudioPlayer.setPlaySpeed(0.4);
  ///
  /// MIN : 0.0
  /// MAX : 16.0
  ///
  /// if null, set to defaultPlaySpeed (1.0)
  ///
  Future<void> setPlaySpeed(double playSpeed) async {
    await _sendChannel.invokeMethod('playSpeed', {
      "id": this.id,
      "playSpeed":
          (playSpeed ?? defaultPlaySpeed).clamp(minPlaySpeed, maxPlaySpeed),
    });
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

  final double volume;
  final bool respectSilentMode;
  final bool showNotification;
  final double playSpeed;

  int playlistIndex = 0;

  int selectNext() {
    if (hasNext()) {
      playlistIndex += 1;
    }
    return playlistIndex;
  }

  int shuffle() {
    Random random = Random();
    playlistIndex = random.nextInt(playlist.audios.length - 1);
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
  Audio audioAt({int at}) {
    if (at < playlist.audios.length) {
      return playlist.audios[at];
    } else {
      return null;
    }
  }

  Audio currentAudio() {
    return audioAt(at: playlistIndex);
  }

  bool hasNext() {
    return playlistIndex + 1 < playlist.numberOfItems;
  }

  _CurrentPlaylist({
    @required this.playlist,
    this.volume,
    this.respectSilentMode,
    this.showNotification,
    this.playSpeed,
  });

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
