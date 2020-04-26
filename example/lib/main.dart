import 'package:assets_audio_player/assets_audio_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter_neumorphic/flutter_neumorphic.dart';
import 'dart:async';

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
    MyAudio(
        name: "Online",
        audio: Audio.network("https://files.freemusicarchive.org/storage-freemusicarchive-org/music/Music_for_Video/springtide/Sounds_strange_weird_but_unmistakably_romantic_Vol1/springtide_-_03_-_We_Are_Heading_to_the_East.mp3"),
        imageUrl: "https://image.shutterstock.com/image-vector/pop-music-text-art-colorful-600w-515538502.jpg"),
    MyAudio(
        name: "Rock",
        audio: Audio("assets/audios/rock.mp3"),
        imageUrl:
            "https://static.radio.fr/images/broadcasts/cb/ef/2075/c300.png"),
    MyAudio(
        name: "Country",
        audio: Audio("assets/audios/country.mp3"),
        imageUrl:
            "https://images-na.ssl-images-amazon.com/images/I/81M1U6GPKEL._SL1500_.jpg"),
    MyAudio(
        name: "Electronic",
        audio: Audio("assets/audios/electronic.mp3"),
        imageUrl: "https://i.ytimg.com/vi/nVZNy0ybegI/maxresdefault.jpg"),
    MyAudio(
        name: "HipHop",
        audio: Audio("assets/audios/hiphop.mp3"),
        imageUrl:
            "https://beyoudancestudio.ch/wp-content/uploads/2019/01/apprendre-danser.hiphop-1.jpg "),
    MyAudio(
        name: "Pop",
        audio: Audio("assets/audios/pop.mp3"),
        imageUrl: "https://image.shutterstock.com/image-vector/pop-music-text-art-colorful-600w-515538502.jpg"),
    MyAudio(
        name: "Instrumental",
        audio: Audio("assets/audios/instrumental.mp3"),
        imageUrl: "https://i.ytimg.com/vi/zv_0dSfknBc/maxresdefault.jpg"),
  ];

  final AssetsAudioPlayer _assetsAudioPlayer = AssetsAudioPlayer();
  final List<StreamSubscription> _subscriptions = [];

  @override
  void initState() {
    _subscriptions.add(_assetsAudioPlayer.playlistFinished.listen((data) {
      print("finished : $data");
    }));
    _subscriptions.add(_assetsAudioPlayer.playlistAudioFinished.listen((data) {
      print("playlistAudioFinished : $data");
    }));
    _subscriptions.add(_assetsAudioPlayer.current.listen((data) {
      print("current : $data");
    }));
    _subscriptions.add(_assetsAudioPlayer.onReadyToPlay.listen((audio) {
      print("onRedayToPlay : $audio");
    }));
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
                SizedBox(
                  height: 20,
                ),
                Stack(
                  fit: StackFit.passthrough,
                  children: <Widget>[
                    StreamBuilder(
                      stream: _assetsAudioPlayer.current,
                      builder: (BuildContext context,
                          AsyncSnapshot<Playing> snapshot) {
                        final Playing playing = snapshot.data;
                        if (playing != null) {
                          final myAudio =
                              find(this.audios, playing.audio.assetAudioPath);
                          return Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Neumorphic(
                              boxShape: NeumorphicBoxShape.circle(),
                              style: NeumorphicStyle(
                                  depth: 8,
                                  surfaceIntensity: 1,
                                  shape: NeumorphicShape.concave),
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
                          AssetsAudioPlayer.playAndForget(Audio("assets/audios/horn.mp3"));
                        },
                        child: Icon(
                          Icons.add_alert,
                          color: Colors.grey[800],
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(
                  height: 20,
                ),
                SizedBox(
                  height: 20,
                ),
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
                                      isPlaylist:
                                          playing.playlist.audios.length > 1,
                                      toggleLoop: () {
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
                                final RealtimePlayingInfos infos =
                                    snapshot.data;
                                //print("infos: $infos");
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
                SizedBox(
                  height: 20,
                ),
                Expanded(
                  child: StreamBuilder(
                      stream: _assetsAudioPlayer.current,
                      builder: (BuildContext context,
                          AsyncSnapshot<Playing> snapshot) {
                        final Playing playing = snapshot.data;
                        return SongsSelector(
                          audios: this.audios,
                          onPlaylistSelected: (myAudios) {
                            _assetsAudioPlayer.open(Playlist(
                                audios: myAudios.map((e) => e.audio).toList()));
                          },
                          onSelected: (myAudio) {
                            _assetsAudioPlayer.open(myAudio.audio, autoStart: false);
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
