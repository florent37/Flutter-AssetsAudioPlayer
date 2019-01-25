import 'package:assets_audio_player_example/asset_audio_player_icons.dart';
import 'package:flutter/material.dart';

import 'package:assets_audio_player/assets_audio_player.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  
  final assets = <String>[
    "song1.mp3",
    "song2.mp3",
    "song3.mp3",
  ];
  final AssetsAudioPlayer _assetsAudioPlayer = AssetsAudioPlayer();

  var _currentAssetPosition = -1;

  void _open(int assetIndex) {
    _currentAssetPosition = assetIndex % assets.length;
    _assetsAudioPlayer.open(
      AssetsAudio(
        asset: assets[_currentAssetPosition],
        folder: "assets/audios/",
      ),
    );
  }

  void _playPause() {
    _assetsAudioPlayer.playOrPause();
  }

  void _next() {
    _currentAssetPosition++;
    _open(_currentAssetPosition);
  }

  void _prev() {
    _currentAssetPosition--;
    _open(_currentAssetPosition);
  }

  @override
  void dispose() {
    _assetsAudioPlayer.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Padding(
          padding: const EdgeInsets.only(bottom: 48.0),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(
                child: StreamBuilder(
                  stream: _assetsAudioPlayer.current,
                  initialData: const PlayingAudio(),
                  builder: (BuildContext context,
                      AsyncSnapshot<PlayingAudio> snapshot) {
                    final PlayingAudio currentAudio = snapshot.data;
                    return ListView.builder(
                      itemBuilder: (context, position) {
                        return ListTile(
                            title: Text(assets[position],
                                style: TextStyle(
                                    color: assets[position] ==
                                            currentAudio.assetAudio.asset
                                        ? Colors.blue
                                        : Colors.black)),
                            onTap: () {
                              _open(position);
                            });
                      },
                      itemCount: assets.length,
                    );
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  StreamBuilder(
                    stream: _assetsAudioPlayer.currentPosition,
                    initialData: const Duration(),
                    builder: (BuildContext context,
                        AsyncSnapshot<Duration> snapshot) {
                      Duration duration = snapshot.data;
                      return Text(durationToString(duration));
                    },
                  ),
                  Text(" - "),
                  StreamBuilder(
                    stream: _assetsAudioPlayer.current,
                    builder: (BuildContext context,
                        AsyncSnapshot<PlayingAudio> snapshot) {
                      Duration duration = Duration();
                      if (snapshot.hasData) {
                        duration = snapshot.data.duration;
                      }
                      return Text(durationToString(duration));
                    },
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.max,
                children: <Widget>[
                  IconButton(
                    onPressed: _prev,
                    icon: Icon(AssetAudioPlayerIcons.to_start),
                  ),
                  StreamBuilder(
                    stream: _assetsAudioPlayer.isPlaying,
                    initialData: false,
                    builder:
                        (BuildContext context, AsyncSnapshot<bool> snapshot) {
                      return IconButton(
                        onPressed: _playPause,
                        icon: Icon(snapshot.data
                            ? AssetAudioPlayerIcons.pause
                            : AssetAudioPlayerIcons.play),
                      );
                    },
                  ),
                  IconButton(
                    icon: Icon(AssetAudioPlayerIcons.to_end),
                    onPressed: _next,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String durationToString(Duration duration) {
  String twoDigits(int n) {
    if (n >= 10) return "$n";
    return "0$n";
  }

  String twoDigitMinutes =
      twoDigits(duration.inMinutes.remainder(Duration.minutesPerHour));
  String twoDigitSeconds =
      twoDigits(duration.inSeconds.remainder(Duration.secondsPerMinute));
  return "$twoDigitMinutes:$twoDigitSeconds";
}