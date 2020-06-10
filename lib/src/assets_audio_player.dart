import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:assets_audio_player/src/notification.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rxdart/rxdart.dart';
import 'package:rxdart/subjects.dart';
import 'package:uuid/uuid.dart';

import 'applifecycle.dart';
import 'notification.dart';
import 'playable.dart';
import 'playing.dart';

export 'applifecycle.dart';
export 'notification.dart';
export 'playable.dart';
export 'playing.dart';

const _DEFAULT_AUTO_START = true;
const _DEFAULT_RESPECT_SILENT_MODE = false;
const _DEFAULT_SHOW_NOTIFICATION = false;
const _DEFAULT_PLAY_IN_BACKGROUND = PlayInBackground.enabled;
const _DEFAULT_PLAYER = "DEFAULT_PLAYER";

const METHOD_POSITION = "player.position";
const METHOD_VOLUME = "player.volume";
const METHOD_FINISHED = "player.finished";
const METHOD_IS_PLAYING = "player.isPlaying";
const METHOD_IS_BUFFERING = "player.isBuffering";
const METHOD_CURRENT = "player.current";
const METHOD_FORWARD_REWIND_SPEED = "player.forwardRewind";
const METHOD_NOTIFICATION_NEXT = "player.next";
const METHOD_NOTIFICATION_PREV = "player.prev";
const METHOD_NOTIFICATION_STOP = "player.stop";
const METHOD_NOTIFICATION_PLAY_OR_PAUSE = "player.playOrPause";
const METHOD_PLAY_SPEED = "player.playSpeed";

enum PlayerState {
  play,
  pause,
  stop,
}

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
  static final NotificationSettings defaultNotificationSettings =
      const NotificationSettings();

  //region notification click
  static MethodChannel _notificationOpenChannel =
      const MethodChannel('assets_audio_player_notification');
  static final BehaviorSubject<ClickedNotificationWrapper>
      __onNotificationClicked = BehaviorSubject<ClickedNotificationWrapper>();
  static final Stream<ClickedNotificationWrapper> _onNotificationClicked =
      __onNotificationClicked.stream;

  static void setupNotificationsOpenAction(NotificationOpenAction action) {
    WidgetsFlutterBinding.ensureInitialized();
    _notificationOpenChannel =
        const MethodChannel('assets_audio_player_notification');
    _notificationOpenChannel.setMethodCallHandler((call) async {
      switch (call.method) {
        case "selectNotification":
          {
            final String audioId = call.arguments;
            __onNotificationClicked.value =
                ClickedNotificationWrapper(ClickedNotification(
              audioId: audioId,
            ));
            break;
          }
      }
    });
    addNotificationOpenAction(action);
  }

  static StreamSubscription addNotificationOpenAction(
      NotificationOpenAction action) {
    return _onNotificationClicked.listen((ClickedNotificationWrapper clicked) {
      if (action != null && !clicked.handled) {
        bool handled = action(clicked.clickedNotification);
        clicked.handled = handled;
      }
    });
  }
  //endregion

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

  final BehaviorSubject<PlayerState> _playerState =
      BehaviorSubject<PlayerState>.seeded(PlayerState.stop);

  ValueStream<PlayerState> get playerState => _playerState.stream;

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

  bool get shuffle => _shuffle.value;

  bool _respectSilentMode = _DEFAULT_RESPECT_SILENT_MODE;

  bool get respectSilentMode => _respectSilentMode;

  bool _showNotification = false;
  bool get showNotification => _showNotification;
  set showNotification(bool newValue) {
    _showNotification = newValue;

    /* await */ _sendChannel.invokeMethod(
        'showNotification', {"id": this.id, "show": _showNotification});
  }

  /// assign the looping state : true -> looping, false -> not looping
  set loop(value) {
    setLoop(value);
  }

  Future<void> setLoop(bool value) async {
    _playlist.loop = value;
    _loop.value = value;
    if (_playlist.isSingleAudio) {
      _loopSingleAudio(value);
    } else {
      _loopSingleAudio(false);
    }
  }

  /// assign the shuffling state : true -> shuffling, false -> not shuffling
  set shuffle(value) {
    _shuffle.value = value;
  }

  /// toggle the looping state
  /// if it was looping -> stops this
  /// if it was'nt looping -> now it is
  void toggleLoop() {
    loop = !loop;
  }

  /// toggle the shuffling state
  /// if it was shuffling -> stops this
  /// if it was'nt shuffling -> now it is
  void toggleShuffle() {
    shuffle = !shuffle;
    _playlist.clearPlayerAudio(shuffle);
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
    _playerState.close();
    _isBuffering.close();
    _forwardRewindSpeed.close();
    _realtimePlayingInfos.close();
    _realTimeSubscription?.cancel();
    _players.remove(this.id);

    WidgetsBinding.instance.removeObserver(_lifecycleObserver);
    _lifecycleObserver = null;
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
        case METHOD_NOTIFICATION_NEXT:
          _notificationNext();
          break;
        case METHOD_NOTIFICATION_PREV:
          _notificationPrevious();
          break;
        case METHOD_NOTIFICATION_STOP:
          _notificationStop();
          break;
        case METHOD_NOTIFICATION_PLAY_OR_PAUSE: //eg: from notification
          _notificationPlayPause();
          break;
        case METHOD_CURRENT:
          if (call.arguments == null) {
            _playlistAudioFinished.add(Playing(
              audio: this._current.value.audio,
              index: this._current.value.index,
              hasNext: false,
              playlist: this._current.value.playlist,
            ));
            _playlistFinished.value = true;
            _current.value = null;
            _playerState.value = PlayerState.stop;
          } else {
            final totalDurationMs =
                _toDuration(call.arguments["totalDurationMs"]);

            final playingAudio = PlayingAudio(
              audio: _lastOpenedAssetsAudio,
              duration: totalDurationMs,
            );

            if (_playlist != null) {
              final current = Playing(
                audio: playingAudio,
                index: _playlist.playlistIndex,
                hasNext: _playlist.hasNext(),
                playlist: ReadingPlaylist(
                    audios: _playlist.playlist.audios,
                    currentIndex: _playlist.playlistIndex,
                    nextIndex: _playlist.nextIndex(),
                    previousIndex: _playlist.previousIndex()),
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
          final bool playing = call.arguments;
          _isPlaying.value = playing;
          _playerState.value = playing ? PlayerState.play : PlayerState.pause;
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
    _registerToAppLifecycle();
  }

  StreamSubscription _realTimeSubscription;

  AppLifecycleObserver _lifecycleObserver;

  bool _wasPlayingBeforeEnterBackground;

  /* = null */
  void _registerToAppLifecycle() {
    _lifecycleObserver = AppLifecycleObserver(onBackground: () {
      if (_playlist != null) {
        switch (_playlist.playInBackground) {
          case PlayInBackground.enabled:
            {
              /* do nothing */
            }
            break;
          case PlayInBackground.disabledPause:
            pause();
            break;
          case PlayInBackground.disabledRestoreOnForeground:
            _wasPlayingBeforeEnterBackground = isPlaying.value ?? false;
            pause();
            break;
        }
      }
    }, onForeground: () {
      if (_playlist != null) {
        switch (_playlist.playInBackground) {
          case PlayInBackground.enabled:
            {
              /* do nothing */
            }
            break;
          case PlayInBackground.disabledPause:
            {
              /* do nothing, keep the pause */
            }
            break;
          case PlayInBackground.disabledRestoreOnForeground:
            if (_wasPlayingBeforeEnterBackground != null) {
              if (_wasPlayingBeforeEnterBackground) {
                play();
              } else {
                /* do nothing, keep the pause */
              }
            }
            break;
        }
      }
    });
    WidgetsBinding.instance.addObserver(_lifecycleObserver);
  }

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
      this.isBuffering
    ])
        .map((values) => RealtimePlayingInfos(
              volume: values[0],
              isPlaying: values[1],
              isLooping: values[2],
              isShuffling: values[3],
              current: values[4],
              currentPosition: values[5],
              isBuffering: values[6],
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

  Future<void> _openPlaylistCurrent(
      {bool autoStart = true, Duration seek}) async {
    if (_playlist != null) {
      return _open(
        _playlist.currentAudio(),
        forcedVolume: _playlist.volume,
        respectSilentMode: _playlist.respectSilentMode,
        showNotification: _playlist.showNotification,
        playSpeed: _playlist.playSpeed,
        notificationSettings: _playlist.notificationSettings,
        autoStart: autoStart,
        loop: _playlist.loop,
        seek: seek,
      );
    }
  }

  Future<bool> next({
    bool stopIfLast = false,
  }) {
    return _next(
      stopIfLast: stopIfLast,
      requestByUser: true,
    );
  }

  Future<bool> _next(
      {bool stopIfLast = false, bool requestByUser = false}) async {
    if (_playlist != null) {
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
      return Duration(milliseconds: 0);
    } else if (value is int) {
      return Duration(milliseconds: value);
    } else if (value is double) {
      return Duration(milliseconds: value.round());
    } else {
      return Duration();
    }
  }

  void _notificationPrevious() {
    if (_playlist?.notificationSettings?.customPrevAction != null) {
      _playlist?.notificationSettings?.customPrevAction(this);
    } else {
      previous();
    }
  }

  void _notificationStop() {
    if (_playlist?.notificationSettings?.customStopAction != null) {
      _playlist?.notificationSettings?.customStopAction(this);
    } else {
      stop();
    }
  }

  void _notificationPlayPause() {
    if (_playlist?.notificationSettings?.customPlayPauseAction != null) {
      _playlist?.notificationSettings?.customPlayPauseAction(this);
    } else {
      playOrPause();
    }
  }

  void _notificationNext() {
    if (_playlist?.notificationSettings?.customNextAction != null) {
      _playlist?.notificationSettings?.customNextAction(this);
    } else {
      next();
    }
  }

  //private method, used in open(playlist) and open(path)
  Future<void> _open(
    Audio audioInput, {
    bool autoStart = _DEFAULT_AUTO_START,
    double forcedVolume,
    bool respectSilentMode = _DEFAULT_RESPECT_SILENT_MODE,
    bool showNotification = _DEFAULT_SHOW_NOTIFICATION,
    Duration seek,
    double playSpeed,
    bool loop,
    NotificationSettings notificationSettings,
  }) async {
    final currentAudio = _lastOpenedAssetsAudio;
    if (audioInput != null) {
      _respectSilentMode = respectSilentMode;
      _showNotification = showNotification;

      final audio = await _handlePlatformAsset(audioInput);

      try {
        Map<String, dynamic> params = {
          "id": this.id,
          "audioType": audioTypeDescription(audio.audioType),
          "path": audio.path,
          "autoStart": autoStart,
          "respectSilentMode": respectSilentMode,
          "displayNotification": showNotification,
          "volume": forcedVolume ?? this.volume.value ?? defaultVolume,
          "playSpeed": playSpeed ?? this.playSpeed.value ?? defaultPlaySpeed,
        };
        if (seek != null) {
          params["seek"] = seek.inMilliseconds.round();
        }
        if (audio.package != null) {
          params["package"] = audio.package;
        }
        if (audio.networkHeaders != null) {
          params["networkHeaders"] = audio.networkHeaders;
        }

        //region notifs
        final notifSettings = notificationSettings ?? NotificationSettings();
        writeNotificationSettingsInto(params, notifSettings);
        //endregion

        writeAudioMetasInto(params, audio.metas);
        _lastOpenedAssetsAudio = audioInput;
        /*final result = */

        await _sendChannel.invokeMethod('open', params);

        await setLoop(loop);

        _playlistFinished.value = false;
      } catch (e) {
        _lastOpenedAssetsAudio = currentAudio; //revert to the previous audio
        print(e);
        return Future.error(e);
      }
    }
  }

  Future<void> onAudioUpdated(Audio audio) async {
    if (_lastOpenedAssetsAudio != null) {
      if (_lastOpenedAssetsAudio.path == audio.path) {
        final Map<String, dynamic> params = {
          "id": this.id,
          "path": audio.path,
        };

        writeAudioMetasInto(params, audio.metas);

        await _sendChannel.invokeMethod('onAudioUpdated', params);
      }
    }
  }

  Future<void> updateCurrentAudioNotification(
      {Metas metas, bool showNotifications = true}) async {
    if (_lastOpenedAssetsAudio != null) {
      final Map<String, dynamic> params = {
        "id": this.id,
        "path": _lastOpenedAssetsAudio,
        "showNotification": showNotifications,
      };

      writeAudioMetasInto(params, metas);

      await _sendChannel.invokeMethod('onAudioUpdated', params);
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
    bool loop,
    NotificationSettings notificationSettings,
    PlayInBackground playInBackground = _DEFAULT_PLAY_IN_BACKGROUND,
  }) async {
    _lastSeek = null;
    _replaceRealtimeSubscription();
    this._playlist = _CurrentPlaylist(
        playlist: playlist,
        volume: volume,
        respectSilentMode: respectSilentMode,
        showNotification: showNotification,
        playSpeed: playSpeed,
        loop: loop,
        notificationSettings: notificationSettings,
        playInBackground: playInBackground);
    _playlist.clearPlayerAudio(shuffle);
    _playlist.moveTo(playlist.startIndex);
    return _openPlaylistCurrent(autoStart: autoStart, seek: seek);
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
    NotificationSettings notificationSettings,
    bool loop = false,
    PlayInBackground playInBackground = _DEFAULT_PLAY_IN_BACKGROUND,
  }) async {
    Playlist playlist;
    if (playable is Playlist &&
        playable.audios != null &&
        playable.audios.length > 0) {
      playlist = playable;
    } else if (playable is Audio) {
      playlist = Playlist(audios: [playable]);
    }

    if (playlist != null) {
      await _openPlaylist(
        playlist,
        autoStart: autoStart,
        volume: volume,
        respectSilentMode: respectSilentMode,
        showNotification: showNotification,
        seek: seek,
        loop: loop,
        playSpeed: playSpeed,
        notificationSettings:
            notificationSettings ?? defaultNotificationSettings,
        playInBackground: playInBackground,
      );
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

  Future<void> _loopSingleAudio(bool loop) async {
    await _sendChannel
        .invokeMethod('loopSingleAudio', {"id": this.id, "loop": loop});
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
    _lastSeek = _currentPosition.value;
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
        "to": to.inMilliseconds.round(),
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

  Future<Audio> _handlePlatformAsset(Audio input) async {
    if (defaultTargetPlatform == TargetPlatform.macOS &&
        input.audioType == AudioType.asset) {
      //on macos assets are not available from native
      final String path = await _copyToTmpMemory(
          package: input.package, assetSource: input.path);
      return input.copyWith(audioType: AudioType.file, path: path);
    }
    return input;
  }

  //returns the file path
  Future<String> _copyToTmpMemory({String package, String assetSource}) async {
    final String fileName = "${package ?? ""}$assetSource";
    final completePath = '${(await getTemporaryDirectory()).path}/$fileName';
    final file = File(completePath);
    if (await file.exists()) {
      return file.path;
    } else {
      await file.create(recursive: true);

      ByteData assetContent;
      if (package == null) {
        assetContent = await rootBundle.load('$assetSource');
      } else {
        assetContent = await rootBundle.load('$package/$assetSource');
      }

      await file.writeAsBytes(assetContent.buffer.asUint8List());

      return file.path;
    }
  }
}

class _CurrentPlaylist {
  final Playlist playlist;

  final double volume;
  final bool respectSilentMode;
  final bool showNotification;
  bool loop;
  final double playSpeed;
  final NotificationSettings notificationSettings;
  final PlayInBackground playInBackground;

  int playlistIndex = 0;

  int nextIndex() {
    int index = indexList.indexWhere((element) => playlistIndex == element);
    if (index + 1 == indexList.length) {
      return indexList.first;
    } else {
      return indexList[index + 1];
    }
  }

  int previousIndex() {
    int index = indexList.indexWhere((element) => playlistIndex == element);
    if (index == 0) {
      return indexList.last;
    } else {
      return indexList[index - 1];
    }
  }

  selectNext() {
    int index = indexList.indexWhere((element) => playlistIndex == element);
    if (hasNext()) {
      index = index + 1;
    }
    playlistIndex = index;
  }

  List<int> indexList = [];

  sortAudios() {
    for (var i = 0; i < this.playlist.audios.length; i++) {
      indexList.add(i);
    }
  }

  clearPlayerAudio(bool shuffle) {
    indexList.clear();
    if (shuffle) {
      shuffleAudios();
    } else {
      sortAudios();
    }
  }

  shuffleAudios() {
    for (var i = 0; i < this.playlist.audios.length; i++) {
      int index = _shuffleNumbers();
      indexList.add(index);
    }
  }

  int _shuffleNumbers() {
    Random random = Random();
    int index = random.nextInt(playlist.audios.length);
    if (indexList.contains(index)) {
      index = _shuffleNumbers();
    }
    return index;
  }

  int moveTo(int index) {
    if (index < 0) {
      playlistIndex = indexList.indexWhere((element) => element == 0);
    } else {
      playlistIndex = indexList.indexWhere((element) => element == index);
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
    return audioAt(at: indexList[playlistIndex]);
  }

  bool hasNext() {
    int index = indexList.indexWhere((element) => playlistIndex == element);
    return index + 1 < indexList.length;
  }

  bool get isSingleAudio => playlist.audios.length == 1;

  _CurrentPlaylist({
    @required this.playlist,
    this.volume,
    this.respectSilentMode,
    this.showNotification,
    this.playSpeed,
    this.notificationSettings,
    this.playInBackground,
    this.loop,
  });

  void returnToFirst() {
    playlistIndex = 0;
  }

  bool hasPrev() {
    int index = indexList.indexWhere((element) => playlistIndex == element);
    return index > 0;
  }

  void selectPrev() {
    int index = indexList.indexWhere((element) => playlistIndex == element);
    index = index - 1;
    playlistIndex = index;
    if (playlistIndex < 0) {
      playlistIndex = 0;
    }
  }
}
