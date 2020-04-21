import 'package:assets_audio_player/assets_audio_player.dart';
import 'package:assets_audio_player_example/player/PlayingControlsSmall.dart';
import 'package:flutter/material.dart';
import 'package:flutter_neumorphic/flutter_neumorphic.dart';

import 'player/PlayingControls.dart';
import 'player/PositionSeekWidget.dart';
import 'player/SongsSelector.dart';
import 'player/VolumeSelector.dart';
import 'player/model/MyAudio.dart';

void main() => runApp(
      NeumorphicTheme(
        theme: NeumorphicThemeData(
          intensity: 0.8,
          lightSource: LightSource.topLeft,
        ),
        child: MyApp(),
      ),
    );

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final audios = <MyAudio>[
    MyAudio(name: "Astronomia", audio: Audio("assets/audios/astronomia.mp3"), imageUrl: "https://m.media-amazon.com/images/I/71Mpo3RQr6L._SS500_.jpg"),
    MyAudio(name: "Interstellar", audio: Audio("assets/audios/interstellar.mp3"), imageUrl: "https://i2.wp.com/www.parentgalactique.fr/wp-content/uploads/2014/11/interstellar.jpg"),
    MyAudio(name: "Counting Moews", audio: Audio("assets/audios/bongocat.mp3"), imageUrl: "http://img.youtube.com/vi/73afc3UOipk/maxresdefault.jpg"),
    MyAudio(name: "Africa Cover (Peter Bence)", audio: Audio("assets/audios/africa.mp3"), imageUrl: "http://img.youtube.com/vi/_SywaUbg5wU/maxresdefault.jpg"),
  ];

  final AssetsAudioPlayer _assetsAudioPlayer = AssetsAudioPlayer();

  @override
  void initState() {
    _assetsAudioPlayer.playlistFinished.listen((data) {
      print("finished : $data");
    });
    _assetsAudioPlayer.playlistAudioFinished.listen((data) {
      print("playlistAudioFinished : $data");
    });
    _assetsAudioPlayer.current.listen((data) {
      print("current : $data");
    });
    super.initState();
  }

  @override
  void dispose() {
    _assetsAudioPlayer.dispose();
    super.dispose();
  }

  MyAudio find(List<MyAudio> source, String fromPath) {
    return source.firstWhere((element) => element.audio.path == fromPath);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: NeumorphicTheme.baseColor(context),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 48.0),
              child: Column(
                  children: this
                      .audios
                      .map(
                        (e) => PlayerWidget(
                          myAudio: e,
                        ),
                      )
                      .toList(),
                ),
            ),
          ),
        ),
      ),
    );
  }
}

class PlayerWidget extends StatefulWidget {
  final MyAudio myAudio;

  @override
  _PlayerWidgetState createState() => _PlayerWidgetState();

  const PlayerWidget({
    @required this.myAudio,
  });
}

class _PlayerWidgetState extends State<PlayerWidget> {
  AssetsAudioPlayer _assetsAudioPlayer = AssetsAudioPlayer.newPlayer();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
        stream: _assetsAudioPlayer.isLooping,
        initialData: false,
        builder: (context, snapshotLooping) {
          final bool isLooping = snapshotLooping.data;
          return StreamBuilder(
              stream: _assetsAudioPlayer.isPlaying,
              initialData: false,
              builder: (context, snapshotPlaying) {
                final isPlaying = snapshotPlaying.data;
                return Neumorphic(
                  margin: EdgeInsets.all(8),
                  padding: const EdgeInsets.all(12.0),
                  boxShape: NeumorphicBoxShape.roundRect(borderRadius: BorderRadius.circular(8)),
                  child: Column(
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            flex: 3,
                            child: Row(
                              children: <Widget>[
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Neumorphic(
                                    boxShape: NeumorphicBoxShape.circle(),
                                    style: NeumorphicStyle(depth: 8, surfaceIntensity: 1, shape: NeumorphicShape.concave),
                                    child: Image.network(
                                      widget.myAudio.imageUrl,
                                      height: 50,
                                      width: 50,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(this.widget.myAudio.name),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          Expanded(
                            flex: 2,
                            child: PlayingControlsSmall(
                              isLooping: isLooping,
                              isPlaying: isPlaying,
                              toggleLoop: () {
                                _assetsAudioPlayer.toggleLoop();
                              },
                              onPlay: () {
                                if (_assetsAudioPlayer.current.value == null) {
                                  _assetsAudioPlayer.open(widget.myAudio.audio, autoStart: true);
                                } else {
                                  _assetsAudioPlayer.playOrPause();
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      StreamBuilder(
                        stream: _assetsAudioPlayer.realtimePlayingInfos,
                        builder: (context, snapshot) {
                          if(!snapshot.hasData){
                            return SizedBox();
                          }
                          RealtimePlayingInfos infos = snapshot.data;
                          return PositionSeekWidget(
                            seekTo: (to){
                              _assetsAudioPlayer.seek(to);
                            },
                            duration: infos.duration,
                            currentPosition: infos.currentPosition,
                          );
                        }
                      ),
                    ],
                  ),
                );
              });
        });
  }
}
