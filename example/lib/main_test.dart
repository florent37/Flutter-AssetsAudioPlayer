import 'package:assets_audio_player/assets_audio_player.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State {
  final audios = [
    Audio.liveStream(
      "http://bbcmedia.ic.llnwd.net/stream/bbcmedia_radio1_mf_p",
      metas: Metas(
        title: "Online",
        artist: "Florent Champigny",
        album: "OnlineAlbum",
        image: MetasImage.network(
            "https://image.shutterstock.com/image-vector/pop-music-text-art-colorful-600w-515538502.jpg"),
      ),
    ),
    Audio.liveStream(
      "http://bbcmedia.ic.llnwd.net/stream/bbcmedia_radio1_mf_p",
      metas: Metas(
        title: "Instrumental",
        artist: "Florent Champigny",
        album: "InstrumentalAlbum",
        image: MetasImage.network(
            "https://i.ytimg.com/vi/zv_0dSfknBc/maxresdefault.jpg"),
      ),
    ),
  ];

  final AssetsAudioPlayer _assetsAudioPlayer = AssetsAudioPlayer();

  @override
  void initState() {
    _assetsAudioPlayer.stop();
    _assetsAudioPlayer.playlistFinished.listen((data) {
      print("finished : $data");
    });
    _assetsAudioPlayer.playlistAudioFinished.listen((data) {
      print("playlistAudioFinished : $data");
    });
    _assetsAudioPlayer.current.listen((data) {
      print("current : $data");
    });
    _assetsAudioPlayer.onReadyToPlay.listen((audio) {
      print("onRedayToPlay : $audio");
    });
    _assetsAudioPlayer.open(
        Playlist(audios: audios),
        showNotification: false,
        playInBackground: PlayInBackground.enabled,
        respectSilentMode: true
    );
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: RaisedButton(
            child: Text('Next'),
            onPressed: () {
              print(_assetsAudioPlayer.current.value);
              _assetsAudioPlayer.next();
              Future.delayed(Duration(seconds: 5), () {
                print(_assetsAudioPlayer.current.value);
              });
            },
          ),
        ),
      ),
    );
  }
}