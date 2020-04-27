import 'package:flutter/foundation.dart';

class Playable {}

enum AudioType {
  network,
  file,
  asset,
}

enum ImageType {
  network,
  file,
  asset,
}

@immutable
class MetasImage {
  final String path;
  final ImageType type;

  const MetasImage.network(this.path) : type = ImageType.network;
  const MetasImage.asset(this.path) : type = ImageType.asset;
  const MetasImage.file(this.path) : type = ImageType.file;
}

@immutable
class Metas {
  final String title;
  final String artist;
  final String album;
  final MetasImage image;

  const Metas({
    this.title,
    this.artist,
    this.album,
    this.image,
  });

}

@immutable
class Audio implements Playable {
  final String path;
  final AudioType audioType;
  final Metas metas;

  const Audio(this.path, {this.metas}) : audioType = AudioType.asset;
  const Audio.file(this.path, {this.metas}) : audioType = AudioType.file;
  const Audio.network(this.path, {this.metas}) : audioType = AudioType.network;
}

@immutable
class Playlist implements Playable {
  final List<Audio> audios;

  final int startIndex;

  const Playlist({@required this.audios, this.startIndex = 0});

  int get numberOfItems => audios.length;
}
