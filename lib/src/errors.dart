import 'package:flutter/foundation.dart';

import 'assets_audio_player.dart';

enum AssetsAudioPlayerErrorType {
  Network,
  Player
}

typedef AssetsAudioPlayerErrorHandler = Function(AssetsAudioPlayerError error, AssetsAudioPlayer player);

AssetsAudioPlayerErrorType parseAssetsAudioPlayerErrorType(String type){
  switch(type){
    case "network" : return AssetsAudioPlayerErrorType.Network;
    default : return AssetsAudioPlayerErrorType.Player;
  }
}

class AssetsAudioPlayerError {
  final AssetsAudioPlayerErrorType errorType;
  final String message;

  const AssetsAudioPlayerError({
    @required this.errorType,
    @required this.message,
  });
}