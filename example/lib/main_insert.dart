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

  static final rock =  Audio(
    "assets/audios/rock.mp3",
    metas: Metas(
      id: "Rock",
      title: "Rock",
      artist: "Florent Champigny",
      album: "RockAlbum",
      image: MetasImage.network(
          "https://static.radio.fr/images/broadcasts/cb/ef/2075/c300.png"),
    ),
  );

  static final country =  Audio(
    "assets/audios/country.mp3",
    metas: Metas(
      id: "Country",
      title: "Country",
      artist: "Florent Champigny",
      album: "CountryAlbum",
      image: MetasImage.asset("assets/images/country.jpg"),
    ),
  );

  final playlist  = Playlist(audios: [rock]);

  final AssetsAudioPlayer _assetsAudioPlayer = AssetsAudioPlayer();

  @override
  void initState() {
    _assetsAudioPlayer.open(this.playlist, showNotification: true);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              RaisedButton(
                child: Text('Insert rock 0'),
                onPressed: () {
                  this.playlist.insert(0, rock);
                },
              ),
              RaisedButton(
                child: Text('Insert country 0'),
                onPressed: () {
                  this.playlist.insert(0, country);
                },
              ),
              RaisedButton(
                child: Text('Insert 3'),
                onPressed: () {
                  this.playlist.insert(3, country);
                },
              ),

              RaisedButton(
                child: Text('Replace 0'),
                onPressed: () {
                  this.playlist.replaceAt(0, (audio){
                    return country;
                  });
                },
              ),
              RaisedButton(
                child: Text('Replace 0 seek'),
                onPressed: () {
                  this.playlist.replaceAt(0, (audio){
                    return country;
                  }, keepPlayingPositionIfCurrent: true);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}