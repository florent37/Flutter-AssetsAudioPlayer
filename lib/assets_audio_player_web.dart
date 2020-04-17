import 'dart:async';
import 'dart:html';

import 'package:assets_audio_player/assets_audio_player.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_howl/howl.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';

/// Web Player
class _WebPlayer {
  final MethodChannel channel;

  _WebPlayer({this.channel});

  Howl _howl;

  get volume => _howl?.volume ?? 1.0;

  set volume(double volume) {
    _howl?.volume(volume);
    channel.invokeMethod(METHOD_VOLUME, volume);
  }

  bool _isPlaying = false;

  get isPlaying => _isPlaying;

  set isPlaying(bool value) {
    _isPlaying = value;
    channel.invokeMethod(METHOD_IS_PLAYING, value);
    if (value) {
      _listenPosition();
    } else {
      _stopListenPosition();
    }
  }

  double get currentPosition => _howl.seek();

  var __listenPosition = false;

  double _duration = 0;
  double _position = 0;

  void _listenPosition() async {
    __listenPosition = true;
    Future.doWhile(() {
      final duration = _howl.duration;
      if (duration != _duration) {
        _duration = duration;
        channel.invokeMethod(METHOD_CURRENT, {"totalDuration": duration});
      }

      if (_position != currentPosition) {
        _position = currentPosition;
        channel.invokeMethod(METHOD_POSITION, currentPosition);
      }
      return Future.delayed(Duration(milliseconds: 200)).then((value) {
        return __listenPosition;
      });
    });
  }

  void _stopListenPosition() {
    __listenPosition = false;
  }

  void play() {
    if (_howl != null) {
      isPlaying = true;
      _howl.play();
    }
  }

  void pause() {
    if (_howl != null) {
      isPlaying = false;
      _howl.pause();
    }
  }

  void stop() {
    if (_howl != null) {
      isPlaying = false;
      _howl.stop();
      channel.invokeMethod(METHOD_POSITION, 0);
    }
  }

  String findAssetPath(String path) {
    //in web, assets are packaged in a /assets/ folder
    //if you want "/asset/3" as described in pubspec
    //it will be in /assets/asset/3

    /* for release mode, need to change the "url", remove the /#/ and add /asset before */
    if (path.startsWith("/")) {
      path = path.replaceFirst("/", "");
    }
    path = (window.location.href.replaceAll("/#/", "") + "/assets/" + path);
    return path;
  }

  void open({String path, double volume, bool autoStart}) async {
    stop();

    _howl = Howl(src: [findAssetPath(path)]);

    if (autoStart) {
      play();
    }
    this.volume = volume;
  }

  void seek({double to}) {
    if (_howl != null) {
      if (to != null) {
        _howl?.seek(to);
      }
    }
  }
}

/// Web plugin
class AssetsAudioPlayerPlugin {
  final Map<String, _WebPlayer> _players = Map();
  final BinaryMessenger messenger;

  AssetsAudioPlayerPlugin({this.messenger}) {
    initializeHowl();
  }

  _WebPlayer _getOrCreate(String id) {
    if (_players.containsKey(id)) {
      return _players[id];
    } else {
      final _WebPlayer newPlayer = _WebPlayer(
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

    final AssetsAudioPlayerPlugin instance =
        AssetsAudioPlayerPlugin(messenger: registrar.messenger);
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
        final String volume = call.arguments["volum"];
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
