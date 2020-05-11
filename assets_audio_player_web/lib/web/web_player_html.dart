import 'dart:async';
import 'dart:html' as html;

import 'package:flutter/services.dart';

import 'abstract_web_player.dart';

/// Web Player
class WebPlayerHtml extends WebPlayer {
  @override
  WebPlayerHtml({MethodChannel channel}) : super(channel: channel);

  StreamSubscription _onEndListener;
  StreamSubscription _onCanPlayListener;

  void _clearListeners() {
    _onEndListener?.cancel();
    _onCanPlayListener?.cancel();
  }

  html.AudioElement _audioElement;

  @override
  get volume => _audioElement?.volume ?? 1.0;

  @override
  set volume(double volume) {
    _audioElement?.volume = volume;
    channel.invokeMethod(WebPlayer.methodVolume, volume);
  }

  @override
  get playSpeed => _audioElement?.playbackRate ?? 1.0;

  @override
  set playSpeed(double playSpeed) {
    _audioElement?.playbackRate = playSpeed;
    channel.invokeMethod(WebPlayer.methodPlaySpeed, playSpeed);
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

  double _duration;
  double _position;

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
      forwardHandler?.stop();
      _audioElement.play();
    }
  }

  @override
  void pause() {
    if (_audioElement != null) {
      isPlaying = false;
      forwardHandler?.stop();
      _audioElement.pause();
    }
  }

  @override
  void stop() {
    forwardHandler?.stop();
    forwardHandler = null;

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
      {String path,
      String audioType,
      double volume,
      double seek,
      bool autoStart,
      double playSpeed}) async {
    stop();
    _duration = null;
    _position = null;
    _audioElement = html.AudioElement(findAssetPath(path, audioType));

    _onEndListener = _audioElement.onEnded.listen((event) {
      channel.invokeMethod(WebPlayer.methodFinished, true);
    });
    _onCanPlayListener = _audioElement.onCanPlay.listen((event) {
      if (autoStart) {
        play();
      }
      this.volume = volume;

      final duration = _audioElement.duration;
      if (duration != _duration) {
        _duration = duration;
        channel
            .invokeMethod(WebPlayer.methodCurrent, {"totalDuration": duration});
      }

      if (seek != null) {
        this.seek(to: seek);
      }

      if (playSpeed != null) {
        this.playSpeed(playSpeed);
      }

      //single event
      _onCanPlayListener?.cancel();
      _onCanPlayListener = null;
    });
  }

  @override
  void seek({double to}) {
    if (_audioElement != null) {
      if (to != null) {
        _audioElement?.currentTime = to;
      }
    }
  }

  void seekBy({double by}) {
    final current = currentPosition;
    final to = current + by;
    seek(to: to);
  }

  ForwardHandler forwardHandler;
  @override
  void forwardRewind(double speed) {
    pause();
    channel.invokeMethod(WebPlayer.methodForwardRewindSpeed, speed);
    if (forwardHandler != null) {
      forwardHandler.stop();
    }
    forwardHandler = ForwardHandler();
    _listenPosition(); //for this usecase, enable listen position
    forwardHandler.start(this, speed);
  }
}

class ForwardHandler {
  bool _isEnabled = false;
  static final _timelapse = 300;

  void start(WebPlayerHtml player, double speed) async {
    _isEnabled = true;
    while (_isEnabled) {
      player.seekBy(by: speed * _timelapse);
      await Future.delayed(Duration(milliseconds: _timelapse));
    }
  }

  void stop() {
    _isEnabled = false;
  }
}
