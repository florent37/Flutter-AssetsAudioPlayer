# assets_audio_player

Play music/audio stored in assets files directly from Flutter

1. Create an audio directory in your assets (not necessary named "audios")
2. Declare it inside your pubspec.yaml

```yaml
flutter:
  assets:
    - assets/audios/
```

## Getting Started

```Dart
AssetsAudioPlayer.open(AssetsAudio(
    asset: "song1.mp3",
    folder: "assets/audios/",
));
```

```Dart
AssetsAudioPlayer.playOrPause();
AssetsAudioPlayer.play();
AssetsAudioPlayer.pause();
```

```Dart
AssetsAudioPlayer.seek(Duration to);
```

```Dart
AssetsAudioPlayer.stop();
```

## Listeners

All listeners exposes Streams 
Using RxDart, AssetsAudioPlayer exposes some listeners as ValueObservable (Observable that provides synchronous access to the last emitted item);

### Current song
```Dart
//The current playing audio, filled with the total song duration
AssetsAudioPlayer.current //ValueObservable<PlayingAudio>

//Retrieve directly the current played asset
final PlayingAudio playing = AssetsAudioPlayer.current.value;

//Listen to the current playing song
AssetsAudioPlayer.current.listen((playingAudio){
    final asset = playingAudio.assetAudio;
    final songDuration = playingAudio.duration;
})
```

### Current position (in seconds)

```Dart
AssetsAudioPlayer.currentPosition //ValueObservable<Duration>

//retrieve directly the current song position
final Duration position = AssetsAudioPlayer.currentPosition.value;

return StreamBuilder(
    stream: AssetsAudioPlayer.currentPosition,
    builder: (context, asyncSnapshot) {
        final Duration duration = asyncSnapshot.data;
        return Text(duration.toString());  
    }),
```

### IsPlaying
boolean observable representing the current mediaplayer playing state
```Dart
AssetsAudioPlayer.isPlaying // ValueObservable<bool>

//retrieve directly the current player state
final bool playing = AssetsAudioPlayer.isPlaying.value;

//will follow the AssetsAudioPlayer playing state
return StreamBuilder(
    stream: AssetsAudioPlayer.isPlaying,
    builder: (context, asyncSnapshot) {
        final bool isPlaying = asyncSnapshot.data;
        return Text(isPlaying ? "Pause" : "Play");  
    }),
```

### Finished

Called when the current song has finished to play

```Dart
AssetsAudioPlayer.finished //ValueObservable<bool>

AssetsAudioPlayer.finished.listen((finished){
    
})
```

# Flutter

For help getting started with Flutter, view our 
[online documentation](https://flutter.io/docs), which offers tutorials, 
samples, guidance on mobile development, and a full API reference.
