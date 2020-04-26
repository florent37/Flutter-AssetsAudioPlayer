import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_web_howl/howl.dart';

import 'abstract_web_player.dart';

/// Web Player
class WebPlayerHowl extends WebPlayer {
  @override
  WebPlayerHowl({MethodChannel channel}) : super(channel: channel);

  Howl _howl;

  @override
  get volume => _howl?.volume ?? 1.0;

  @override
  set volume(double volume) {
    _howl?.volume(volume);
    channel.invokeMethod(WebPlayer.methodVolume, volume);
  }

  bool _isPlaying = false;

  @override
  get isPlaying => _isPlaying;

  @override
  set isPlaying(bool value) {
    _isPlaying = value;
    channel.invokeMethod(WebPlayer.methodIsPlaying, value);
    if (value) {
      _listenPosition();
    } else {
      _stopListenPosition();
    }
  }

  @override
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
        channel
            .invokeMethod(WebPlayer.methodCurrent, {"totalDuration": duration});
      }

      if (_position != currentPosition) {
        _position = currentPosition;
        channel.invokeMethod(WebPlayer.methodPosition, currentPosition);
      }
      return Future.delayed(Duration(milliseconds: 200)).then((value) {
        return __listenPosition;
      });
    });
  }

  void _stopListenPosition() {
    __listenPosition = false;
  }

  @override
  void play() {
    if (_howl != null) {
      isPlaying = true;
      _howl.play();
    }
  }

  @override
  void pause() {
    if (_howl != null) {
      isPlaying = false;
      _howl.pause();
    }
  }

  @override
  void stop() {
    if (_howl != null) {
      isPlaying = false;
      _howl.stop();
      channel.invokeMethod(WebPlayer.methodPosition, 0);
    }
  }

  @override
  Future<void> open(
      {String path,
      String audioType,
      double volume,
      double seek,
      bool autoStart}) async {
    stop();

    _howl = Howl(src: [findAssetPath(path, audioType)]);

    if (autoStart) {
      play();
    }
    this.volume = volume;
    if (seek != null) {
      this.seek(to: seek);
    }
  }

  @override
  void seek({double to}) {
    if (_howl != null) {
      if (to != null) {
        _howl?.seek(to);
      }
    }
  }
}
