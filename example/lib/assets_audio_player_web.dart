import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';

class _WebPlayer {}

class AssetsAudioPlayerPlugin {
  final Map<String, _WebPlayer> _players = Map();

  _WebPlayer _getOrCreate(String id) {
    if (_players.containsKey(id)) {
      return _players[id];
    } else {
      final _WebPlayer newPlayer = _WebPlayer();
      _players[id] = newPlayer;
      return newPlayer;
    }
  }

  static void registerWith(Registrar registrar) {
    final MethodChannel channel = MethodChannel(
      'assets_audio_player',
      const StandardMethodCodec(),
      registrar.messenger,
    );

    final AssetsAudioPlayerPlugin instance = AssetsAudioPlayerPlugin();
    channel.setMethodCallHandler(instance.handleMethodCall);
  }

  Future<dynamic> handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case "isPlaying":
        final String id = call.arguments["id"];
        return _getOrCreate(id).isPlaying();
        break;
      case "play":
        final String id = call.arguments["id"];
        return _getOrCreate(id).play();
        break;
      case "pause":
        final String id = call.arguments["id"];
        return _getOrCreate(id).pause();
        break;
      case "stop":
        final String id = call.arguments["id"];
        return _getOrCreate(id).stop();
        break;
      case "volume":
        final String id = call.arguments["id"];
        final double volume = call.arguments["volume"];
        return _getOrCreate(id).setVolume(
          volume: volume,
        );
        break;
      case "seek":
        final String id = call.arguments["id"];
        final double to = call.arguments["to"];
        return _getOrCreate(id).seek(
          to: to,
        );
        break;
      case "open":
        final String id = call.arguments["id"];
        final String path = call.arguments["path"];
        final bool autoStart = call.arguments["autoStart"] ?? true;
        return _getOrCreate(id).open(
            path: path,
            autoStart: autoStart,
        );
        break;
    }
  }
}
