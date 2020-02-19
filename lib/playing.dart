import 'package:flutter/foundation.dart';

import 'playable.dart';

/// Represents the current played audio asset
/// When the player opened a song, it will ping AssetsAudioPlayer.current with a `AssetsAudio`
///
/// ### Example
///     final assetAudio = AssetsAudio(
///       assets/audios/song1.mp3,
///     )
///
///     _assetsAudioPlayer.current.listen((PlayingAudio current){
///         //ex: retrieve the current song's total duration
///     });
///
///     _assetsAudioPlayer.open(assetAudio);
///
@immutable
class PlayingAudio {
  ///the opened asset
  final String assetAudioPath;

  ///the current song's total duration
  final Duration duration;

  const PlayingAudio({
    this.assetAudioPath = "",
    this.duration = Duration.zero,
  });
}

@immutable
class ReadingPlaylist {
  final List<Audio> audios;
  final int currentIndex;

  const ReadingPlaylist({@required this.audios, this.currentIndex = 0});
}

@immutable
class Playing { //TODO rename
  ///the opened asset
  final PlayingAudio audio;

  /// this audio index in playlist
  final int index;

  /// if this audio has a next element (if no : last element)
  final bool hasNext;

  /// the parent playlist
  final ReadingPlaylist playlist;

  Playing({
    @required this.audio,
    @required this.index,
    @required this.hasNext,
    @required this.playlist,
  });
}
