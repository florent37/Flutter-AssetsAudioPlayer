import 'package:flutter/foundation.dart';

class Playable {}

enum AudioType {
  network,
  file,
  asset,
}

@immutable
class Audio implements Playable {
  final String path;
  final AudioType audioType;

  const Audio(this.path) : audioType = AudioType.asset;
  const Audio.file(this.path) : audioType = AudioType.file;
  const Audio.network(this.path) : audioType = AudioType.network;


}

@immutable
class Playlist implements Playable {
  final List<Audio> audios;

  final int startIndex;

  const Playlist({@required this.audios, this.startIndex = 0});

  int get numberOfItems => audios.length;
}
