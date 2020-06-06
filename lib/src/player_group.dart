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
  final bool respectSilentMode ;
  final PlayInBackground playInBackground ;

  final PlayerGroupMetasCallback updateNotification;

  final PlayerGroupCallback onNotificationOpened;

  final PlayerGroupCallback onNotificationPlay;
  final PlayerGroupCallback onNotificationPaused;
  final PlayerGroupCallback onNotificationStop;

  const AssetAudioPlayerGroup({
    this.showNotification = _DEFAULT_SHOW_NOTIFICATION,

    this.updateNotification,
    this.onNotificationOpened,
    this.onNotificationPlay,
    this.onNotificationPaused,
    this.onNotificationStop,

    this.respectSilentMode = _DEFAULT_RESPECT_SILENT_MODE,
    this.playInBackground = _DEFAULT_PLAY_IN_BACKGROUND,

  });

  Future<void> add(Audio audio, {
    bool autoStart = _DEFAULT_AUTO_START,
    bool loop = false,
    double volume,
    Duration seek,
    double playSpeed,
  }){
    //TODO
  }

  void dispose(){
    //TODO
  }
}
