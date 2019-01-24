import 'dart:async';

import 'package:flutter/services.dart';
import 'package:rxdart/rxdart.dart';
import 'package:rxdart/subjects.dart';

class AssetsAudio {
  final String asset;
  final String folder;

  const AssetsAudio({this.asset, this.folder});
}

class PlayingAudio {
  final AssetsAudio assetAudio;
  final Duration duration;

  const PlayingAudio({this.assetAudio = const AssetsAudio(), this.duration});
}

class AssetsAudioPlayer {
  static AssetsAudioPlayerPlugin _plugin = AssetsAudioPlayerPlugin._();
  static ValueObservable<PlayingAudio> get current => _plugin.current;
  static ValueObservable<bool> get isPlaying => _plugin.isPlaying;
  static ValueObservable<bool> get finished => _plugin.finished;
  static ValueObservable<Duration> get currentPosition =>
      _plugin.currentPosition;
  static Stream<bool> get next => _plugin.next;
  static Stream<bool> get prev => _plugin.prev;

  static void open(AssetsAudio assetAudio) {
    _plugin.open(assetAudio);
  }

  static void playOrPause() async {
    _plugin.playOrPause();
  }

  static void play() {
    _plugin.play();
  }

  static void pause() {
    _plugin.pause();
  }

  static void seek(Duration to) {
    _plugin.seek(to);
  }

  static void stop() {
    _plugin.stop();
      }
    }
    
    class AssetsAudioPlayerPlugin {
      final MethodChannel _channel = const MethodChannel('assets_audio_player');
    
      final BehaviorSubject<bool> _isPlaying =
          BehaviorSubject<bool>(seedValue: false);
      ValueObservable<bool> get isPlaying => _isPlaying.stream;
    
      final BehaviorSubject<PlayingAudio> _current =
          BehaviorSubject<PlayingAudio>();
      ValueObservable<PlayingAudio> get current => _current.stream;
    
      final BehaviorSubject<bool> _finished =
          BehaviorSubject<bool>(seedValue: false);
      ValueObservable<bool> get finished => _isPlaying.stream;
    
      final BehaviorSubject<Duration> _currentPosition =
          BehaviorSubject<Duration>(seedValue: const Duration());
      Stream<Duration> get currentPosition => _currentPosition.stream;
    
      final PublishSubject<bool> _next = PublishSubject<bool>();
      Stream<bool> get next => _next.stream;
    
      final PublishSubject<bool> _prev = PublishSubject<bool>();
      Stream<bool> get prev => _prev.stream;
    
      AssetsAudio _lastOpenedAssetsAudio;
    
      void dispose() {
        _currentPosition.close();
        _isPlaying.close();
        _next.close();
        _prev.close();
        _finished.close();
      }
    
      AssetsAudioPlayerPlugin._() {
        _channel.setMethodCallHandler((MethodCall call) async {
          //print("received call ${call.method} with arguments ${call.arguments}");
          switch (call.method) {
            case 'log':
              print("log: " + call.arguments);
              break;
            case 'player.finished':
              _finished.value = call.arguments;
              break;
            case 'player.current':
              final totalDuration = toDuration(call.arguments["totalDuration"]);
    
              _current.value = PlayingAudio(
                assetAudio: _lastOpenedAssetsAudio,
                duration: totalDuration,
              );
              break;
            case 'player.next':
              _next.add(true);
              break;
            case 'player.prev':
              _prev.add(true);
              break;
            case 'player.position':
              if (call.arguments is int) {
                _currentPosition.value = Duration(seconds: call.arguments);
              } else if (call.arguments is double) {
                double value = call.arguments;
                _currentPosition.value = Duration(seconds: value.round());
              }
              break;
            case 'player.isPlaying':
              _isPlaying.value = call.arguments;
              break;
            default:
              print('[ERROR] Channel method ${call.method} not implemented.');
          }
        });
      }
    
      Duration toDuration(num value) {
        if (value is int) {
          return Duration(seconds: value);
        } else if (value is double) {
          return Duration(seconds: value.round());
        } else {
          return Duration();
        }
      }
    
      void open(AssetsAudio assetAudio) async {
        String assetName = assetAudio.asset;
        if (assetName.startsWith("/")) {
          assetName = assetName.substring(1);
        }
        String folder = assetAudio.folder;
        if (folder.endsWith("/")) {
          folder = folder.substring(0, folder.length - 1);
        }
        if (folder.startsWith("/")) {
          folder = folder.substring(1);
        }
    
        try {
          _channel.invokeMethod(
              'open', <String, dynamic>{'file': assetName, 'folder': folder});
        } catch (e) {
          print(e);
        }
    
         _lastOpenedAssetsAudio = assetAudio;
    
      }
    
      void playOrPause() async {
        final bool playing = _isPlaying.value;
        if (playing) {
          pause();
        } else {
          play();
        }
      }
    
      void play() {
        _channel.invokeMethod('play');
      }
    
      void pause() {
        _channel.invokeMethod('pause');
      }
    
      void seek(Duration to) {
        _channel.invokeMethod('seek', to.inSeconds.round());
      }
    
      void stop() {
        _channel.invokeMethod('stop');
      }
}
