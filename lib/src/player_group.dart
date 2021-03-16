import 'dart:async';

import 'package:assets_audio_player/assets_audio_player.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:rxdart/rxdart.dart';

typedef PlayerGroupCallback = void Function(
    AssetsAudioPlayerGroup playerGroup, List<PlayingAudio> audios);
typedef PlayerGroupMetasCallback = Future<PlayerGroupMetas> Function(
    AssetsAudioPlayerGroup playerGroup, List<PlayingAudio> audios);

const _DEFAULT_RESPECT_SILENT_MODE = false;
const _DEFAULT_SHOW_NOTIFICATION = false;
const _DEFAULT_NOTIFICATION_STOP_ENABLED = true;
const _DEFAULT_PLAY_IN_BACKGROUND = PlayInBackground.enabled;

class AudioFinished {
  final AssetsAudioPlayerGroup playerGroup;
  final PlayingAudio audio;

  AudioFinished(this.playerGroup, this.audio);
}

class AssetsAudioPlayerGroup {
  final MethodChannel _sendChannel = const MethodChannel('assets_audio_player');

  final bool showNotification;
  final bool respectSilentMode;

  final bool notificationStopEnabled;

  final PlayInBackground playInBackground;

  AssetsAudioPlayerGroupErrorHandler onErrorDo; //custom error Handler

  final PlayerGroupMetasCallback updateNotification;

  final PlayerGroupCallback onNotificationOpened;

  final PlayerGroupCallback onNotificationPlay;
  final PlayerGroupCallback onNotificationPause;
  final PlayerGroupCallback onNotificationStop;

  final Map<Audio, AssetsAudioPlayer> _audiosWithPlayers = {};

  //copy of _audiosWithPlayers
  Map<Audio, AssetsAudioPlayer> get audiosWithPlayers =>
      Map.from(_audiosWithPlayers);

  List<Audio> get audios => _audiosWithPlayers.keys.toList();
  List<AssetsAudioPlayer> get players => _audiosWithPlayers.values.toList();

  final List<StreamSubscription> _subscriptions = [];

  final BehaviorSubject<bool> _isPlaying = BehaviorSubject<bool>.seeded(false);

  ValueStream<bool> get isPlaying => _isPlaying.stream;

  //TODO add streams for audio finished

  AssetsAudioPlayerGroup({
    this.showNotification = _DEFAULT_SHOW_NOTIFICATION,
    @required this.updateNotification,
    this.notificationStopEnabled = _DEFAULT_NOTIFICATION_STOP_ENABLED,
    this.onNotificationOpened,
    this.onNotificationPlay,
    this.onNotificationPause,
    this.onNotificationStop,
    this.respectSilentMode = _DEFAULT_RESPECT_SILENT_MODE,
    this.playInBackground = _DEFAULT_PLAY_IN_BACKGROUND,
  }) {
    //default action, can be overriden using player.onErrorDo = (error, player) { ACTION };
    this.onErrorDo = (group, errorHandler) {
      print(errorHandler.error.message);
      errorHandler.player.stop();
    };
  }

  List<PlayingAudio> get playingAudios {
    final List<PlayingAudio> audios = <PlayingAudio>[];
    for (final player in players) {
      final audio = player.current?.value?.audio;
      if (audio != null) {
        audios.add(audio);
      }
    }
    return audios;
  }

  NotificationSettings __notificationSettings;

  //intialize the first time
  NotificationSettings get _notificationSettings {
    if (__notificationSettings == null) {
      __notificationSettings = NotificationSettings(
          stopEnabled: this.notificationStopEnabled,
          seekBarEnabled: false,
          nextEnabled: false,
          prevEnabled: false,
          customPlayPauseAction: (player) {
            if (player.isPlaying.value) {
              if (this.onNotificationPause != null) {
                this.onNotificationPause(this, playingAudios);
              } else {
                _pause();
              }
            } else {
              if (this.onNotificationPlay != null) {
                this.onNotificationPlay(this, playingAudios);
              } else {
                _play();
              }
            }
          },
          customStopAction: (player) {
            if (this.onNotificationStop != null) {
              this.onNotificationStop(this, playingAudios);
            } else {
              _stop();
            }
          });
    }
    return __notificationSettings;
  }


  Future<Map> add(
    Playlist playlist, {
    LoopMode loopMode = LoopMode.none,
    double volume,
    Duration seek,
    double playSpeed,
  }) async {
    final player = AssetsAudioPlayer.newPlayer();


    try {
      await player.open(
        playlist,
        showNotification: false,
        //not need here, we'll call another method `changeNotificationForGroup`
        seek: seek,
        autoStart: isPlaying.value,
        //need to play() for player group
        volume: volume,
        loopMode: loopMode,
        respectSilentMode: respectSilentMode,
        playInBackground: playInBackground,
        playSpeed: playSpeed,
        notificationSettings: _notificationSettings,
      );

      await _addPlayer(playlist, player);
      return {"data": player};
    } on PlatformException catch (e) {
      return {"error": e.toString()};
    }

  }

  Future<void> addAll(List<Playlist> audios) async {
    for (Playlist audio in audios) await add(audio);
  }

  Future<void> removeAudio(Audio audio) async {
    _audiosWithPlayers.remove(audio);
    await _onPlayersChanged();
  }

  Future<void> _removePlayer(AssetsAudioPlayer player) async {
    _audiosWithPlayers.removeWhere((audio, p) => player == p);
    await _onPlayersChanged();
  }

  Future<void> _addPlayer(Playlist audios, AssetsAudioPlayer player) async {
    StreamSubscription finishedSubscription;
    finishedSubscription = player.playlistFinished.listen((finished) {
      if (finished) {
        finishedSubscription.cancel();
        _subscriptions.remove(finishedSubscription);
        _removePlayer(player);
      }
    });

    _subscriptions.add(finishedSubscription);
    _audiosWithPlayers[audios.audios[0]] = player;
    await _onPlayersChanged();
  }

  void _onPlayerError(ErrorHandler errorHandler) {
    if (this.onErrorDo != null) {
      this.onErrorDo(this, errorHandler);
    }
  }

  ///Called when an audio is added or removed (/finished)
  Future<void> _onPlayersChanged() async {
    if (updateNotification != null) {
      final bool isPlaying = this.isPlaying.value;
      final newNotificationsMetas =
          await updateNotification(this, playingAudios);

      String firstPlayerId;
      if (audios.isNotEmpty) {
        firstPlayerId = players.first?.id;
      }

      changeNotificationForGroup(
        //TODO find a way to protect it
        this,
        isPlaying: isPlaying,
        firstPlayerId: firstPlayerId,
        display: playingAudios.isNotEmpty,
        notificationSettings: this._notificationSettings,
        metas: Metas(
          title: newNotificationsMetas.title,
          artist: newNotificationsMetas.subTitle,
          image: newNotificationsMetas.image,
        ),
      );
    }
  }

  Future<void> changeNotificationForGroup(
    AssetsAudioPlayerGroup playerGroup, {
    Metas metas,
    bool display,
    String firstPlayerId,
    NotificationSettings notificationSettings,
    bool isPlaying = true,
  }) async {
    if (playerGroup != null) {
      final Map<String, dynamic> params = {
        "id": firstPlayerId,
        "isPlaying": isPlaying,
        "display": display,
      };

      writeAudioMetasInto(params, metas);
      writeNotificationSettingsInto(params, notificationSettings);

      await _sendChannel.invokeMethod('forceNotificationForGroup', params);
    }
  }

  Future<void> play() {
    return _play();
  }

  Future<void> _play({AssetsAudioPlayer except}) async {
    for (AssetsAudioPlayer player in players) {
      if (player != except) {
        await player.play();
      }
    }
    _isPlaying.value = true;
    await _onPlayersChanged();
  }

  Future<void> pause() {
    return _pause();
  }

  Future<void> _pause({AssetsAudioPlayer except}) async {
    for (AssetsAudioPlayer player in players) {
      if (player != except) {
        await player.pause();
      }
    }
    _isPlaying.value = false;
    await _onPlayersChanged();
  }

  Future<void> stop() {
    return _stop();
  }

  Future<void> _stop({AssetsAudioPlayer except}) async {
    //copy _players because _stop remove the player from the list
    final List<AssetsAudioPlayer> copyList = List.from(players);
    for (AssetsAudioPlayer player in copyList) {
      if (player != except) {
        await player.stop();
      }
    }
    _isPlaying.value = false;
    await _onPlayersChanged();
  }

  void dispose() {
    _subscriptions.forEach((element) {
      element.cancel();
    });
    _subscriptions.clear();
    players.forEach((element) {
      element.dispose();
    });

    _isPlaying.close();
  }

  Future<void> playOrPause() async {
    if (isPlaying.value) {
      await pause();
    } else {
      await play();
    }
  }
}
