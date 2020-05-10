import 'dart:async';

import 'package:assets_audio_player/assets_audio_player.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

void main() => runApp(
      MaterialApp(
        home: MediaPlayer(
          getSongNo: 0,
          subChapterID: "0",
        ),
      ),
    );

class MediaPlayer extends StatefulWidget {
  MediaPlayer({this.getSongNo, this.subChapterID});

  final int getSongNo;
  final String subChapterID;

  @override
  _MediaPlayerState createState() => _MediaPlayerState();
}

class _MediaPlayerState extends State<MediaPlayer> {
  int color = 0XFF2A5F0F;
  int buttonColor = 0XFFFFFF00;
  //SharedPreferences prefs;
  String _timeString;
  final AssetsAudioPlayer _assetsAudioPlayer = AssetsAudioPlayer();
  final List<StreamSubscription> _subscriptions = [];
  bool playing = true;
  String assetType = 'assets/playpause.png';
  Duration currentPosition;

  String nextSOng;
  String chapterMediaID;
  String lastPlayedDuration;
  int songNo = 0;
  DateTime currentBackPressTime;

  @override
  void initState() {
    songNo = widget.getSongNo;
    _timeString = _formatDateTime(DateTime.now());
    Timer.periodic(Duration(seconds: 1), (Timer t) => _getTime());
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
    setState(() {
      getDashboard();
      getColor();
    });
    super.initState();
  }

  @override
  void dispose() {
    _assetsAudioPlayer.dispose();
    super.dispose();
  }

  Future<void> getDashboard() async {
    //var dashboardData = await WebConfig.audioURL(widget.subChapterID);
    updateUI("dashboardData");
  }

  void updateUI(dynamic responseData) {
    if (responseData == null) {
      return;
    } else {
      setState(() {
        try {
          nextSOng =
              "https://files.freemusicarchive.org/storage-freemusicarchive-org/music/Music_for_Video/springtide/Sounds_strange_weird_but_unmistakably_romantic_Vol1/springtide_-_03_-_We_Are_Heading_to_the_East.mp3";
          chapterMediaID = "chapterMediaID";
          lastPlayedDuration = "00:00:10";
          //nextSOng = responseData['medias'][songNo]['media_url'];
          //chapterMediaID = responseData['medias'][songNo]['chapter_media_id'];
          //lastPlayedDuration = responseData['medias'][songNo]['last_played'];
          _assetsAudioPlayer.open(Audio.network(nextSOng),
              seek: parseDuration(lastPlayedDuration));
        } catch (e) {
          print('THIS NEVER GETS PRINTED');
          //Fluttertoast.showToast(msg: 'No More Song');
        }
      });
    }
  }

  Duration parseDuration(String s) {
    int hours = 0;
    int minutes = 0;
    int micros;
    List<String> parts = s.split(':');
    if (parts.length > 2) {
      hours = int.parse(parts[parts.length - 3]);
    }
    if (parts.length > 1) {
      minutes = int.parse(parts[parts.length - 2]);
    }
    micros = (double.parse(parts[parts.length - 1])).round();
    print('$hours----$minutes----$micros');
    return Duration(hours: hours, minutes: minutes, seconds: micros);
  }

  getColor() async {
    //prefs = await SharedPreferences.getInstance();
    color = /* prefs.getInt('ColorValue') ?? */ 0XFF2A5F0F;
    buttonColor = /* prefs.getInt('buttonValue') ?? */ 0XFFFFFF00;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        DateTime now = DateTime.now();
        if (currentBackPressTime == null ||
            now.difference(currentBackPressTime) > Duration(seconds: 2)) {
          currentBackPressTime = now;
          //print(loginData);
          Navigator.pop(context);
          return Future.value(false);
        }
        return Future.value(true);
      },
      child: Scaffold(
        backgroundColor: Color(color),
        body: Stack(
          children: <Widget>[
            Container(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/dashboard.png'),
                  fit: BoxFit.fitHeight,
                ),
              ),
            ),
            Container(
              width: double.infinity,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Column(
                    children: <Widget>[
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                        },
                        child: Container(
                            alignment: Alignment.centerLeft,
                            margin: EdgeInsets.only(left: 20.0),
                            child: Icon(
                              Icons.arrow_back,
                              size: 50.0,
                            )),
                      ),
                      Text(
                        _timeString,
                        textScaleFactor: 0.8,
                        style: TextStyle(
                          fontFamily: 'MessiriMedium',
                          fontSize: 2 * 24.3,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          _assetsAudioPlayer.pause();
                        },
                        child: Text(
                          'QURAN',
                          textScaleFactor: 0.8,
                          style: TextStyle(
                              fontFamily: 'MessiriMedium',
                              fontSize: 2 * 15.3,
                              letterSpacing: 20.0),
                        ),
                      ),
                      StreamBuilder(
                          stream: _assetsAudioPlayer.realtimePlayingInfos,
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return SizedBox();
                            }
                            final RealtimePlayingInfos infos = snapshot.data;
                            currentPosition = infos.currentPosition;
//                          print(currentPosition);
                            return Text("PositionSeekWidget");
                            /*
                            return PositionSeekWidget(
                              currentPosition: infos.currentPosition,
                              duration: infos.duration,
                              seekTo: (to) {
                                _assetsAudioPlayer.seek(to);
                              },
                            );
                             */
                          }),
                      Padding(
                        padding: const EdgeInsets.only(
                            left: 10.0, right: 10.0, bottom: 10.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            GestureDetector(
                              onTap: () async {
                                if (songNo == 0) {
                                  //Fluttertoast.showToast(msg: 'No More Song');
                                } else {
                                  //var loginData = await WebConfig.pauseUrl(
                                  //    currentPosition.toString(),
                                  //    chapterMediaID);
                                  //print(loginData);
                                  songNo = songNo - 1;
                                  getDashboard();
                                }
                              },
                              child: Container(
                                child: Text(
                                  'assets/previous.png',
                                  //color: Color(buttonColor),
                                  //height: 2 * 15.3,
                                ),
                              ),
                            ),
//                            GestureDetector(
//                              onTap: () async{
//                                var loginData = await WebConfig.pauseUrl(currentPosition.toString(), chapterMediaID);
//                                print(loginData);
//                                setState(() {
//                                  if (playing == true) {
//                                    _assetsAudioPlayer.pause();
////                                    _assetsAudioPlayer.stop();
//                                    assetType = 'assets/play.png';
//                                    playing = false;
//                                  } else if (playing == false) {
//                                    _assetsAudioPlayer.play();
//                                    assetType = 'assets/playpause.png';
//                                    playing = true;
//                                  }
//                                });
//                              },
//                              child: Container(
//                                child: Image.asset(
//                                  assetType,
//                                  color: Color(buttonColor),
//                                  height: 20 * 15.3,
//                                ),
//                              ),
//                            ),
                            StreamBuilder(
                                stream: _assetsAudioPlayer.isPlaying,
                                initialData: false,
                                builder: (context, snapshotPlaying) {
                                  final isPlaying = snapshotPlaying.data;
                                  this.playing =
                                      isPlaying; //update using this value
                                  return GestureDetector(
                                      onTap: () async {
                                        var loginData =
                                            //await WebConfig.pauseUrl(
                                            //    currentPosition.toString(),
                                            //    chapterMediaID);
                                            //print(loginData);
                                            setState(() {
                                          if (isPlaying == true) {
                                            //here use isPlaying
                                            _assetsAudioPlayer
                                                .playOrPause(); //call pause
                                          } else {
                                            _assetsAudioPlayer.play();
                                          }
                                        });
                                      },
                                      child: Container(
                                        child: Text(
                                          isPlaying
                                              ? 'assets/playpause.png'
                                              : 'assets/play.png',
                                          //here you can just use isPlaying
                                          //color: Color(buttonColor),
                                          //height: 20 *
                                          //    15.3,
                                        ),
                                      ));
                                }),
                            GestureDetector(
                              onTap: () async {
                                //var loginData = await WebConfig.pauseUrl(
                                //    currentPosition.toString(), chapterMediaID);
                                //print(loginData);
                                songNo = songNo + 1;
                                getDashboard();
                              },
                              child: Container(
                                child: Text(
                                  'assets/next.png',
                                  //color: Color(buttonColor),
                                  //height: 2 * 15.3,
                                ),
                              ),
                            )
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 10.0, right: 10.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            GestureDetector(
                              onTap: () {
                                Duration duration = Duration(seconds: 10);
                                _assetsAudioPlayer
                                    .seek(currentPosition - duration);
                              },
                              child: Container(
                                child: Text(
                                  'assets/10secleft.png',
                                  //color: Color(buttonColor),
                                  //height: 2 * 15.3,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                Duration duration = Duration(seconds: 10);
                                _assetsAudioPlayer.seekBy(duration);
                              },
                              child: Container(
                                child: Text(
                                  'assets/10.png',
                                  //color: Color(buttonColor),
                                  //height: 2 * 15.3,
                                ),
                              ),
                            )
                          ],
                        ),
                      ),
                      /*
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
                      StreamBuilder(
                          stream: _assetsAudioPlayer.playSpeed,
                          initialData: AssetsAudioPlayer.defaultPlaySpeed,
                          builder: (context, snapshot) {
                            final double playSpeed = snapshot.data;
                            return PlaySpeedSelector(
                              playSpeed: playSpeed,
                              onChange: (v) {
                                _assetsAudioPlayer.setPlaySpeed(v);
                              },
                            );
                          }),
                          
                       */
                    ],
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return dateTime.toString();
  }

  void _getTime() {
    final DateTime now = DateTime.now();
    final String formattedDateTime = _formatDateTime(now);
    _timeString = formattedDateTime;
  }
}
