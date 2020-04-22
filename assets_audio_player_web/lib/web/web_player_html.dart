import 'dart:async';
import 'dart:html' as html;

import 'package:flutter/services.dart';

import 'abstract_web_player.dart';

/// Web Player
class WebPlayerHtml extends WebPlayer {
  @override
  WebPlayerHtml({MethodChannel channel}) : super(channel: channel);

  StreamSubscription _onEndListener;

  void _clearListeners() {
    _onEndListener?.cancel();
  }

  html.AudioElement _audioElement;

  @override
  get volume => _audioElement?.volume ?? 1.0;

  @override
  set volume(double volume) {
    _audioElement?.volume = volume;
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
  double get currentPosition => _audioElement.currentTime;

  var __listenPosition = false;

  double _duration = 0;
  double _position = 0;

  void _listenPosition() async {
    __listenPosition = true;
    Future.doWhile(() {
      final duration = _audioElement.duration;
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
    if (_audioElement != null) {
      isPlaying = true;
      _audioElement.play();
    }
  }

  @override
  void pause() {
    if (_audioElement != null) {
      isPlaying = false;
      _audioElement.pause();
    }
  }

  @override
  void stop() {
    _clearListeners();

    if (_audioElement != null) {
      isPlaying = false;
      pause();
      _audioElement.currentTime = 0;
      channel.invokeMethod(WebPlayer.methodPosition, 0);
    }
  }

  @override
  Future<void> open(
      {String path, String audioType, double volume, bool autoStart}) async {
    stop();

    _audioElement = html.AudioElement(findAssetPath(path, audioType));

    _onEndListener = _audioElement.onEnded.listen((event) {
      channel.invokeMethod(WebPlayer.methodFinished, true);
    });

    if (autoStart) {
      play();
    }
    this.volume = volume;
  }

  @override
  void seek({double to}) {
    if (_audioElement != null) {
      if (to != null) {
        _audioElement?.currentTime = to;
      }
    }
  }
}
