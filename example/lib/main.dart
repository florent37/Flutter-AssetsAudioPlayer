import 'package:assets_audio_player/assets_audio_player.dart';
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
          child: Padding(
            padding: const EdgeInsets.only(bottom: 48.0),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SizedBox(height: 20,),
                Stack(
                  fit: StackFit.passthrough,
                  children: <Widget>[
                    StreamBuilder(
                      stream: _assetsAudioPlayer.current,
                      builder: (BuildContext context, AsyncSnapshot<Playing> snapshot) {
                        final Playing playing = snapshot.data;
                        if (playing != null) {
                          final myAudio = find(this.audios, playing.audio.assetAudioPath);
                          return Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Neumorphic(
                              boxShape: NeumorphicBoxShape.circle(),
                              style: NeumorphicStyle(depth: 8, surfaceIntensity: 1, shape: NeumorphicShape.concave),
                              child: Image.network(
                                myAudio.imageUrl,
                                height: 150,
                                width: 150,
                                fit: BoxFit.contain,
                              ),
                            ),
                          );
                        }
                        return SizedBox();
                      },
                    ),
                    Align(
                      alignment: Alignment.topRight,
                      child: NeumorphicButton(
                        boxShape: NeumorphicBoxShape.circle(),
                        padding: EdgeInsets.all(18),
                        margin: EdgeInsets.all(18),
                        onClick: () {
                          AssetsAudioPlayer.newPlayer().open(Audio("assets/audios/horn.mp3"));
                        },
                        child: Icon(
                          Icons.add_alert,
                          color: Colors.grey[800],
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20,),
                SizedBox(height: 20,),
                StreamBuilder(
                    stream: _assetsAudioPlayer.current,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return SizedBox();
                      }
                      final Playing playing = snapshot.data;
                      return Column(
                        children: <Widget>[
                          StreamBuilder(
                            stream: _assetsAudioPlayer.isLooping,
                            initialData: false,
                            builder: (context, snapshotLooping) {
                              final bool isLooping = snapshotLooping.data;
                              return StreamBuilder(
                                  stream: _assetsAudioPlayer.isPlaying,
                                  initialData: false,
                                  builder: (context, snapshotPlaying) {
                                    final isPlaying = snapshotPlaying.data;
                                    return PlayingControls(
                                      isLooping: isLooping,
                                      isPlaying: isPlaying,
                                      isPlaylist: playing.playlist.audios.length > 1,
                                      toggleLoop: (){
                                        _assetsAudioPlayer.toggleLoop();
                                      },
                                      onPlay: () {
                                        _assetsAudioPlayer.playOrPause();
                                      },
                                      onNext: () {
                                        _assetsAudioPlayer.next();
                                      },
                                      onPrevious: () {
                                        _assetsAudioPlayer.previous();
                                      },
                                    );
                                  });
                            },
                          ),
                          StreamBuilder(
                              stream: _assetsAudioPlayer.realtimePlayingInfos,
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) {
                                  return SizedBox();
                                }
                                final RealtimePlayingInfos infos = snapshot.data;
                                print("infos: $infos");
                                return PositionSeekWidget(
                                  currentPosition: infos.currentPosition,
                                  duration: infos.duration,
                                  seekTo: (to) {
                                    _assetsAudioPlayer.seek(to);
                                  },
                                );
                              }),
                        ],
                      );
                    }),
                SizedBox(height: 20,),
                Expanded(
                  child: StreamBuilder(
                      stream: _assetsAudioPlayer.current,
                      builder: (BuildContext context, AsyncSnapshot<Playing> snapshot) {
                        final Playing playing = snapshot.data;
                        return SongsSelector(
                          audios: this.audios,
                          onPlaylistSelected: (myAudios) {
                            _assetsAudioPlayer.open(Playlist(audios: myAudios.map((e) => e.audio).toList()));
                          },
                          onSelected: (myAudio) {
                            _assetsAudioPlayer.open(myAudio.audio);
                          },
                          playing: playing,
                        );
                      }),
                ),
                StreamBuilder(
                    stream: _assetsAudioPlayer.volume,
                    initialData: AssetsAudioPlayer.defaultVolume,
                    builder: (context, snapshot) {
                      final double volume = snapshot.data;
                      return VolumeSelector(
                        volume: volume,
                        onChange: (v) {
                          _assetsAudioPlayer.setVolume(v);
                        },
                      );
                    }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
