import 'dart:async';

import 'package:assets_audio_player_web/web/web_player.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_howl/howl.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';

/// Web plugin
class AssetsAudioPlayerWebPlugin {
  final Map<String, WebPlayer> _players = Map();
  final BinaryMessenger messenger;

  AssetsAudioPlayerWebPlugin({this.messenger}) {
    initializeHowl();
  }

  WebPlayer _getOrCreate(String id) {
    if (_players.containsKey(id)) {
      return _players[id];
    } else {
      final WebPlayer newPlayer = WebPlayer(
        channel: MethodChannel(
          'assets_audio_player/' + id,
          const StandardMethodCodec(),
          this.messenger,
        ),
      );
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

    final instance = AssetsAudioPlayerWebPlugin(messenger: registrar.messenger);
    channel.setMethodCallHandler(instance.handleMethodCall);
  }

  Future<dynamic> handleMethodCall(MethodCall call) async {
    //print(call.method);
    switch (call.method) {
      case "isPlaying":
        final String id = call.arguments["id"];
        return Future.value(_getOrCreate(id).isPlaying());
        break;
      case "play":
        final String id = call.arguments["id"];
        _getOrCreate(id).play();
        return Future.value(true);
        break;
      case "pause":
        final String id = call.arguments["id"];
        _getOrCreate(id).pause();
        return Future.value(true);
        break;
      case "stop":
        final String id = call.arguments["id"];
        _getOrCreate(id).stop();
        return Future.value(true);
        break;
      case "volume":
        final String id = call.arguments["id"];
        final double volume = call.arguments["volume"];
        _getOrCreate(id).volume = volume;
        return Future.value(true);
        break;
      case "seek":
        final String id = call.arguments["id"];
        final double to = call.arguments["to"];
        _getOrCreate(id).seek(
          to: to,
        );
        return Future.value(true);
        break;
      case "open":
        final String id = call.arguments["id"];
        final String path = call.arguments["path"];
        final double volume = call.arguments["volume"];
        final bool autoStart = call.arguments["autoStart"] ?? true;
        return _getOrCreate(id).open(
          path: path,
          volume: volume,
          autoStart: autoStart,
        );
        break;
    }
  }
}
