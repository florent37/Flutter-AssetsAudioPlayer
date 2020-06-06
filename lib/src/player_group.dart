import 'dart:async';

import 'package:assets_audio_player/assets_audio_player.dart';
import 'package:flutter/foundation.dart';

class PlayerGroupMetas {
  final String title;
  final String subTitle;
  final MetasImage image;

  PlayerGroupMetas({
    this.title,
    this.subTitle,
    this.image,
  });
}

typedef PlayerGroupCallback = void Function(AssetAudioPlayerGroup playerGroup, List<PlayingAudio> audios);
typedef PlayerGroupMetasCallback = Future<PlayerGroupMetas> Function(AssetAudioPlayerGroup playerGroup, List<PlayingAudio> audios);

const _DEFAULT_AUTO_START = true;
const _DEFAULT_RESPECT_SILENT_MODE = false;
const _DEFAULT_SHOW_NOTIFICATION = false;
const _DEFAULT_PLAY_IN_BACKGROUND = PlayInBackground.enabled;

class AssetAudioPlayerGroup {
  final bool showNotification;
  final bool respectSilentMode;

  final PlayInBackground playInBackground;

  final PlayerGroupMetasCallback updateNotification;

  final PlayerGroupCallback onNotificationOpened;

  final PlayerGroupCallback onNotificationPlay;
  final PlayerGroupCallback onNotificationPaused;
  final PlayerGroupCallback onNotificationStop;

  final List<AssetsAudioPlayer> _players = [];

  final List<StreamSubscription> _subscriptions = [];

  AssetAudioPlayerGroup({
    this.showNotification = _DEFAULT_SHOW_NOTIFICATION,

    this.updateNotification,
    this.onNotificationOpened,
    this.onNotificationPlay,
    this.onNotificationPaused,
    this.onNotificationStop,

    this.respectSilentMode = _DEFAULT_RESPECT_SILENT_MODE,
    this.playInBackground = _DEFAULT_PLAY_IN_BACKGROUND,
  });

  List<PlayingAudio> get playingAudios => _players.map((e) =>
    e.current.value.audio
  ).toList();

  Future<void> add(Audio audio, {
    bool autoStart = _DEFAULT_AUTO_START,
    bool loop = false,
    double volume,
    Duration seek,
    double playSpeed,
  }) {
    final player = AssetsAudioPlayer.newPlayer();
    player.open(audio, showNotification: false,
      seek: seek,
      autoStart: autoStart,
      volume: volume,
      loop: loop,
      respectSilentMode: respectSilentMode,
      playInBackground: playInBackground,
      playSpeed: playSpeed
    );
    addPlayer(player);
  }

  Future<void> removePlayer(AssetsAudioPlayer player) {
    bool removed = _players.remove(player);
    if(removed) {
      _onPlayersChanged();
    }
  }

  Future<void> addPlayer(AssetsAudioPlayer player) {
    StreamSubscription finishedSubscription;
    finishedSubscription = player.playlistFinished.listen((event) {
      finishedSubscription.cancel();
      _subscriptions.remove(finishedSubscription);
      removePlayer(player);
    });
    _subscriptions.add(finishedSubscription);
    _players.add(player);
    _onPlayersChanged();
  }

  ///Called when an audio is added or removed (/finished)
  void _onPlayersChanged() async {
    if(updateNotification != null) {
      final metas = await updateNotification(this, playingAudios);
      //TODO
    }
  }

  Future<void> play(){
    return Future.wait(
        _players.map(
                (e) => e.play()
        ).toList()
    );
  }

  Future<void> pause(){
    return Future.wait(
        _players.map(
                (e) => e.pause()
        ).toList()
    );
  }

  Future<void> stop(){
    return Future.wait(
        _players.map(
                (e) => e.stop()
        ).toList()
    );
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
}
