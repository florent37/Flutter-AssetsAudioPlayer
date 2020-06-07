import 'dart:async';

import 'package:assets_audio_player/assets_audio_player.dart';
import 'package:rxdart/rxdart.dart';

typedef PlayerGroupCallback = void Function(AssetsAudioPlayerGroup playerGroup, List<PlayingAudio> audios);
typedef PlayerGroupMetasCallback = Future<PlayerGroupMetas> Function(AssetsAudioPlayerGroup playerGroup, List<PlayingAudio> audios);

const _DEFAULT_RESPECT_SILENT_MODE = false;
const _DEFAULT_SHOW_NOTIFICATION = false;
const _DEFAULT_PLAY_IN_BACKGROUND = PlayInBackground.enabled;

class AudioFinished {
  final AssetsAudioPlayerGroup playerGroup;
  final PlayingAudio audio;

  AudioFinished(this.playerGroup, this.audio);
}

class AssetsAudioPlayerGroup {

  final bool showNotification;
  final bool respectSilentMode;

  final PlayInBackground playInBackground;

  final PlayerGroupMetasCallback updateNotification;

  final PlayerGroupCallback onNotificationOpened;

  final PlayerGroupCallback onNotificationPlay;
  final PlayerGroupCallback onNotificationPause;
  final PlayerGroupCallback onNotificationStop;

  final List<AssetsAudioPlayer> _players = [];

  final List<StreamSubscription> _subscriptions = [];

  final BehaviorSubject<bool> _isPlaying = BehaviorSubject<bool>.seeded(false);
  ValueStream<bool> get isPlaying => _isPlaying.stream;

  //TODO add streams for audio finished

  AssetsAudioPlayerGroup({
    this.showNotification = _DEFAULT_SHOW_NOTIFICATION,

    this.updateNotification,
    this.onNotificationOpened,
    this.onNotificationPlay,
    this.onNotificationPause,
    this.onNotificationStop,

    this.respectSilentMode = _DEFAULT_RESPECT_SILENT_MODE,
    this.playInBackground = _DEFAULT_PLAY_IN_BACKGROUND,
  });

  List<PlayingAudio> get playingAudios =>
      _players.map((e) =>
      e.current.value.audio
      ).toList();

  NotificationSettings __notificationSettings;
  //intialize the first time
  NotificationSettings get _notificationSettings {
    if (__notificationSettings == null) {
      __notificationSettings = NotificationSettings(
          stopEnabled: true,
          seekBarEnabled: false,
          customPlayPauseAction: (player) {
            if (player.isPlaying.value) {
              if(this.onNotificationPause != null){
                this.onNotificationPause(this, playingAudios);
              } else {
                _pause();
              }
            } else {
              if(this.onNotificationPlay != null){
                this.onNotificationPlay(this, playingAudios);
              } else {
                _play();
              }
            }
          },
          customStopAction: (player) {
            if(this.onNotificationStop != null){
              this.onNotificationStop(this, playingAudios);
            } else {
              _stop();
            }
          }
      );
    }
    return __notificationSettings;
  }

  Future<void> add(Audio audio, {
    bool loop = false,
    double volume,
    Duration seek,
    double playSpeed,
  }) async {
    final player = AssetsAudioPlayer.newPlayer();
    player.open(audio,
      showNotification: false, //not need here, we'll call another method `changeNotificationForGroup`
      seek: seek,
      autoStart: isPlaying.value, //need to play() for player group
      volume: volume,
      loop: loop,
      respectSilentMode: respectSilentMode,
      playInBackground: playInBackground,
      playSpeed: playSpeed,
      notificationSettings: _notificationSettings,
    );
    await _addPlayer(player);
  }

  Future<void> addAll(List<Audio> audios, {
    bool loop = false,
    double volume,
    Duration seek,
    double playSpeed,
  }) async {
    for(Audio audio in audios)(
      await this.add(audio,
        seek: seek,
        volume: volume,
        loop: loop,
        playSpeed: playSpeed,
      )
    );
  }

  Future<void> removeAudio(Audio audio) async {
    for(AssetsAudioPlayer player in _players){
      if(player.current?.value?.audio?.audio == audio){
        await _removePlayer(player);
      }
    }
  }

  Future<void> _removePlayer(AssetsAudioPlayer player) async {
    bool removed = _players.remove(player);
    if (removed) {
      await _onPlayersChanged();
    }
  }

  Future<void> _addPlayer(AssetsAudioPlayer player) async {
    StreamSubscription finishedSubscription;
    finishedSubscription = player.playlistFinished.listen((event) {
      finishedSubscription.cancel();
      _subscriptions.remove(finishedSubscription);
      _removePlayer(player);
    });
    _subscriptions.add(finishedSubscription);
    _players.add(player);
    await _onPlayersChanged();
  }

  ///Called when an audio is added or removed (/finished)
  Future<void> _onPlayersChanged() async {
    if (updateNotification != null) {
      final bool isPlaying = this.isPlaying.value;
      final newNotificationsMetas = await updateNotification(this, playingAudios);
      if (_players.isNotEmpty) {
        final firstPlayer = _players.first;
        firstPlayer.changeNotificationForGroup( //TODO find a way to protect it
          this,
          isPlaying: isPlaying,
          metas: Metas(
              title: newNotificationsMetas.title,
              artist: newNotificationsMetas.subTitle,
              image: newNotificationsMetas.image
          ),
        );
      }
    }
  }

  Future<void> play() {
    return _play();
  }

  Future<void> _play({AssetsAudioPlayer except}) async {
    for (AssetsAudioPlayer player in _players) {
      if (player != except) {
        await player.play();
      }
    }
    _isPlaying.value = true;
  }

  Future<void> pause() {
    return _pause();
  }

  Future<void> _pause({AssetsAudioPlayer except}) async {
    for (AssetsAudioPlayer player in _players) {
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
    for (AssetsAudioPlayer player in _players) {
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
    _players.forEach((element) {
      element.dispose();
    });
  }

  Future<void> playOrPause() async {
    if(isPlaying.value){
      await pause();
    } else {
      await play();
    }
  }
}
