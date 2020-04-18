import 'dart:async';
import 'dart:html';

import 'package:flutter/services.dart';
import 'package:flutter_web_howl/howl.dart';

/// Web Player
class WebPlayer {
  final MethodChannel channel;

  static final methodPosition = "player.position";
  static final methodVolume = "player.volume";
  static final methodFinished = "player.finished";
  static final methodIsPlaying = "player.isPlaying";
  static final methodCurrent = "player.current";

  WebPlayer({this.channel});

  Howl _howl;

  get volume => _howl?.volume ?? 1.0;

  set volume(double volume) {
    _howl?.volume(volume);
    channel.invokeMethod(methodVolume, volume);
  }

  bool _isPlaying = false;

  get isPlaying => _isPlaying;

  set isPlaying(bool value) {
    _isPlaying = value;
    channel.invokeMethod(methodIsPlaying, value);
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
        channel.invokeMethod(methodCurrent, {"totalDuration": duration});
      }

      if (_position != currentPosition) {
        _position = currentPosition;
        channel.invokeMethod(methodPosition, currentPosition);
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
      channel.invokeMethod(methodPosition, 0);
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
