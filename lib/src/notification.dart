import 'package:flutter/foundation.dart';

import '../assets_audio_player.dart';

typedef NotificationAction = void Function(AssetsAudioPlayer player);

@immutable
class NotificationSettings {
  //region configs
  /// both android & ios
  final bool nextEnabled;
  /// both android & ios
  final bool playPauseEnabled;
  /// both android & ios
  final bool prevEnabled;

  /// android only
  final bool stopEnabled;
  //endregion

  //region customizers
  /// null for default behavior
  final NotificationAction customNextAction;

  /// null for default behavior
  final NotificationAction customPlayPauseAction;

  /// null for default behavior
  final NotificationAction customPrevAction;
  //endregion

  const NotificationSettings({
    this.playPauseEnabled = true,
    this.nextEnabled = true,
    this.prevEnabled = true,
    this.stopEnabled = true,
    this.customNextAction,
    this.customPlayPauseAction,
    this.customPrevAction,
  });
}
