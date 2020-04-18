# assets_audio_player

[![pub package](https://img.shields.io/pub/v/assets_audio_player.svg)](
https://pub.dartlang.org/packages/assets_audio_player)

You like the package ? buy me a kofi :)

<a href='https://ko-fi.com/A160LCC' target='_blank'><img height='36' style='border:0px;height:36px;' src='https://az743702.vo.msecnd.net/cdn/kofi1.png?v=0' border='0' alt='Buy Me a Coffee at ko-fi.com' /></a>

Play music/audio stored in assets files (simultaneously) directly from Flutter (android / ios / web). 

```yaml
dependencies:
  assets_audio_player: ^1.3.6
```

And if you wan [web support, enable web](https://flutter.dev/web) then add
```yaml
dependencies:
  assets_audio_player_web: ^1.3.6
```

No needed to copy songs to a media cache, with assets_audio_player you can open them directly from the assets. 

1. Create an audio directory in your assets (not necessary named "audios")
2. Declare it inside your pubspec.yaml

```yaml
flutter:
  assets:
    - assets/audios/
```

## Getting Started

```Dart
final assetsAudioPlayer = AssetsAudioPlayer();

assetsAudioPlayer.open(
    Audio("assets/audios/song1.mp3"),
);
```

```Dart
assetsAudioPlayer.playOrPause();
assetsAudioPlayer.play();
assetsAudioPlayer.pause();
```

```Dart
assetsAudioPlayer.seek(Duration to);
```

```Dart
assetsAudioPlayer.stop();
```

# Play in parallel / simultaneously

You can create new AssetsAudioPlayer using AssetsAudioPlayer.newPlayer(), 
which will play songs in a different native Media Player

This will enable to play two songs simultaneously

You can have as many player as you want !

```dart
///play 3 songs in parallel
AssetsAudioPlayer.newPlayer().open(
    Audio("assets/audios/song1.mp3")
);
AssetsAudioPlayer.newPlayer().open(
    Audio("assets/audios/song2.mp3")
);
AssetsAudioPlayer.newPlayer().open(
    Audio("assets/audios/song3.mp3")
);
```

Each player has an unique generated `id`, you can retrieve or create them manually using 

```dart
final player = AssetsAudioPlayer(id: "MY_UNIQUE_ID")
```

# Playlist
```Dart
assetsAudioPlayer.open(
  Playlist(
    assetAudioPaths: [
      "assets/audios/song1.mp3",
      "assets/audios/song2.mp3"
    ]
  )
);

assetsAudioPlayer.next();
assetsAudioPlayer.prev();
assetsAudioPlayer.playAtIndex(1);
```

## Listeners

All listeners exposes Streams 
Using RxDart, AssetsAudioPlayer exposes some listeners as ValueObservable (Observable that provides synchronous access to the last emitted item);

### Current song
```Dart
//The current playing audio, filled with the total song duration
assetsAudioPlayer.current //ValueObservable<PlayingAudio>

//Retrieve directly the current played asset
final PlayingAudio playing = assetsAudioPlayer.current.value;

//Listen to the current playing song
assetsAudioPlayer.current.listen((playingAudio){
    final asset = playingAudio.assetAudio;
    final songDuration = playingAudio.duration;
})
```

### Current song duration

```Dart
//Listen to the current playing song
final duration = assetsAudioPlayer.current.value.duration;
```

### Current position (in seconds)

```Dart
assetsAudioPlayer.currentPosition //ValueObservable<Duration>

//retrieve directly the current song position
final Duration position = assetsAudioPlayer.currentPosition.value;

return StreamBuilder(
    stream: assetsAudioPlayer.currentPosition,
    builder: (context, asyncSnapshot) {
        final Duration duration = asyncSnapshot.data;
        return Text(duration.toString());  
    }),
```

### IsPlaying
boolean observable representing the current mediaplayer playing state
```Dart
assetsAudioPlayer.isPlaying // ValueObservable<bool>

//retrieve directly the current player state
final bool playing = assetsAudioPlayer.isPlaying.value;

//will follow the AssetsAudioPlayer playing state
return StreamBuilder(
    stream: assetsAudioPlayer.isPlaying,
    builder: (context, asyncSnapshot) {
        final bool isPlaying = asyncSnapshot.data;
        return Text(isPlaying ? "Pause" : "Play");  
    }),
```

### Volume

Change the volume (between 0.0 & 1.0)
```Dart
assetsAudioPlayer.setVolume(0.5);
```

Listen the volume

```dart
return StreamBuilder(
    stream: assetsAudioPlayer.volume,
    builder: (context, asyncSnapshot) {
        final double volume = asyncSnapshot.data;
        return Text("volume : $volume");  
    }),
```

### Finished

Called when the current song has finished to play, 

it gives the Playing audio that just finished

```Dart
assetsAudioPlayer.playlistAudioFinished //ValueObservable<Playing>

assetsAudioPlayer.playlistAudioFinished.listen((Playing playing){
    
})
```

Called when the complete playlist has finished to play

```Dart
assetsAudioPlayer.playlistFinished //ValueObservable<bool>

assetsAudioPlayer.playlistFinished.listen((finished){
    
})
```

### Looping

```Dart
final bool isLooping = assetsAudioPlayer.loop; //true / false

assetsAudioPlayer.loop = true; //set loop as true

assetsAudioPlayer.isLooping.listen((loop){
    //listen to loop
})

assetsAudioPlayer.toggleLoop(); //toggle the value of looping
```

# Web Support

Web support is using [import_js_library](https://pub.dev/packages/import_js_library) to import the [Howler.js library](https://howlerjs.com/)

The flutter wrapper of Howler has been exported in another package : https://github.com/florent37/flutter_web_howl

# Flutter

For help getting started with Flutter, view our 
[online documentation](https://flutter.io/docs), which offers tutorials, 
samples, guidance on mobile development, and a full API reference.
