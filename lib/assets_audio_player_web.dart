import 'dart:async';
import 'dart:html';

import 'package:assets_audio_player/assets_audio_player.dart';
import 'package:dart_web_audio/dart_web_audio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';

final AudioContext _audioContext = AudioContext();

class _WebPlayer {
  final MethodChannel channel;
  String _currentUrl;

  _WebPlayer({this.channel});

  //the time when the user clicked on play
  double _startingPoint;
  double _soughtPosition;
  double _pausedAt;

  double _currentVolume = 1.0;

  get volume => _currentVolume;

  set volume(double volume) {
    _currentVolume = volume;
    _gainNode?.gain?.value = volume;
    channel.invokeListMethod(METHOD_VOLUME, volume);
  }

  bool _isPlaying = false;

  get isPlaying => _isPlaying;

  set isPlaying(value) {
    _isPlaying = value;
    channel.invokeListMethod(METHOD_IS_PLAYING, value);
    if (value) {
      _listenPosition();
    } else {
      _stopListenPosition();
    }
  }

  AudioBuffer _currentBuffer;
  AudioBufferSourceNode _currentNode;
  GainNode _gainNode;

  double get currentPosition => _audioContext.currentTime - _startingPoint + _soughtPosition;

  var __listenPosition = false;

  void _listenPosition() async {
    __listenPosition = true;
    Future.doWhile(() {
      channel.invokeMethod(METHOD_POSITION, currentPosition);
      return Future.delayed(Duration(milliseconds: 200)).then((value) {
        return __listenPosition;
      });
    });
  }

  void _stopListenPosition() {
    __listenPosition = false;
  }

  void _start(double position) {
    if (_currentBuffer == null) {
      return; // nothing to play yet
    }
    if (_currentNode == null) {
      _createNode();
    }

    _startingPoint = _audioContext.currentTime;
    _soughtPosition = position;

    _currentNode.start(_startingPoint, _soughtPosition);

    isPlaying = true;
  }

  void play() {
    _start(_pausedAt ?? 0);
  }

  void pause() {
    _pausedAt = currentPosition;
    _cancel();
  }

  void stop() {
    _pausedAt = 0;
    _soughtPosition = 0;
    channel.invokeMethod(METHOD_POSITION, 0);
    _cancel();
  }

  void _cancel() {
    isPlaying = false;

    _currentNode?.stop();
    _currentNode = null;
  }

  void open({String path, bool autoStart}) async {

    final HttpRequest response = await HttpRequest.request(path, responseType: 'arraybuffer');
    final AudioBuffer buffer = await _audioContext.decodeAudioData(response.response);

    _currentUrl = path;
    print("$path");

    stop();
    _currentBuffer = buffer;
    _createNode();

    final duration = _currentNode.buffer.duration;
    channel.invokeMethod(METHOD_CURRENT, {
      "totalDuration": duration
    });

    if (autoStart) {
      play();
    }
  }

  void _createNode() {
    _currentNode = _audioContext.createBufferSource();
    _currentNode.buffer = _currentBuffer;
    _currentNode.loop = false;

    _gainNode = _audioContext.createGain();
    _gainNode.gain.value = 1.0;
    _gainNode.connect(_audioContext.destination);

    _currentNode.connect(_gainNode);
  }

  void seek({double to}) {
    if(to != null) {
      pause();
      _start(to);
    }
  }
}

class AssetsAudioPlayerPlugin {
  final Map<String, _WebPlayer> _players = Map();
  final BinaryMessenger messenger;

  AssetsAudioPlayerPlugin({this.messenger});

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

    final AssetsAudioPlayerPlugin instance = AssetsAudioPlayerPlugin(messenger: registrar.messenger);
    channel.setMethodCallHandler(instance.handleMethodCall);
  }

  Future<dynamic> handleMethodCall(MethodCall call) async {
    print(call.method);
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
        final bool autoStart = call.arguments["autoStart"] ?? true;
        return _getOrCreate(id).open(
          path: path,
          autoStart: autoStart,
        );
        break;
    }
  }
}
