import 'dart:async';
import 'dart:html';

import 'package:dart_web_audio/dart_web_audio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';

final AudioContext _audioContext = AudioContext();

class _WebPlayer {
  static final _METHOD_VOLUME = "player.volume";

  final MethodChannel channel;

  _WebPlayer({this.channel});

  //the time when the user clicked on play
  double startingPoint;
  double soughtPosition;
  double pausedAt;
  double currentVolume = 1.0;
  String currentUrl;
  bool _isPlaying = false;

  AudioBuffer currentBuffer;
  AudioBufferSourceNode currentNode;
  GainNode gainNode;

  double get currentPosition => _audioContext.currentTime - startingPoint;

  void _setUrlAndBuffer(String url, AudioBuffer buffer) {
    currentUrl = url;

    stop();
    currentBuffer = buffer;
    _createNode();
    if (_isPlaying) {
      play();
    }
  }

  void _start(double position) {
    _isPlaying = true;
    if (currentBuffer == null) {
      return; // nothing to play yet
    }
    if (currentNode == null) {
      _createNode();
    }
    startingPoint = _audioContext.currentTime;
    soughtPosition = position;
    currentNode.start(startingPoint, soughtPosition);
  }

  void play() {
    _start(pausedAt ?? 0);
  }

  void pause() {
    pausedAt = _audioContext.currentTime - startingPoint + soughtPosition;
    _cancel();
  }

  void stop() {
    pausedAt = 0;
    _cancel();
  }

  void _cancel() {
    _isPlaying = false;
    currentNode?.stop();
    currentNode = null;
  }

  //void seek({double to}) {
  //  return Future.value(true);
  //}

  void setVolume({double volume}) {
    gainNode?.gain?.value = volume;
    channel.invokeMethod(_METHOD_VOLUME, volume);
  }

  void open({String path, bool autoStart}) async {
    final AudioBuffer buffer = await loadAudio(path);
    _setUrlAndBuffer(path, buffer);
    _start(0);
  }

  Future<AudioBuffer> loadAudio(String url) async {
    final HttpRequest response = await HttpRequest.request(url, responseType: 'arraybuffer');
    final AudioBuffer buffer = await _audioContext.decodeAudioData(response.response);
    return buffer;
  }

  void _createNode() {
    currentNode = _audioContext.createBufferSource();
    currentNode.buffer = currentBuffer;
    currentNode.loop = false;

    gainNode = _audioContext.createGain();
    gainNode.gain.value = 1.0;
    gainNode.connect(_audioContext.destination);

    currentNode.connect(gainNode);
  }

  Future<bool> isPlaying() {
    return Future.value(_isPlaying);
  }

  void seek({double to}) {
    //TODO
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
    switch (call.method) {
      case "isPlaying":
        final String id = call.arguments["id"];
        _getOrCreate(id).isPlaying();
        return Future.value(true);
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
        _getOrCreate(id).setVolume(
          volume: volume,
        );
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
