import 'package:flutter/foundation.dart';

class Playable {}

enum AudioType {
  network,
  liveStream,
  file,
  asset,
}

extension AudioTypeDescription on AudioType {
  String description() {
    switch (this) {
      case AudioType.network:
        return "network";
      case AudioType.liveStream:
        return "liveStream";
      case AudioType.file:
        return "file";
      case AudioType.asset:
        return "asset";
    }
    return null;
  }
}

enum ImageType {
  network,
  file,
  asset,
}

extension ImageTypeDescription on ImageType {
  String description() {
    switch (this) {
      case ImageType.network:
        return "network";
      case ImageType.file:
        return "file";
      case ImageType.asset:
        return "asset";
    }
    return null;
  }
}

@immutable
class MetasImage {
  final String path;
  final String package;
  final ImageType type;

  const MetasImage.network(this.path)
      : type = ImageType.network,
        package = null;
  const MetasImage.asset(
    this.path, {
    this.package,
  }) : type = ImageType.asset;
  const MetasImage.file(this.path)
      : type = ImageType.file,
        package = null;
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
  final String package;
  final AudioType audioType;
  final Metas metas;

  const Audio(this.path, {this.metas, this.package})
      : audioType = AudioType.asset;
  const Audio.file(this.path, {this.metas})
      : audioType = AudioType.file,
        package = null;
  const Audio.network(this.path, {this.metas})
      : audioType = AudioType.network,
        package = null;
  const Audio.liveStream(this.path, {this.metas})
      : audioType = AudioType.liveStream,
        package = null;
}

@immutable
class Playlist implements Playable {
  final List<Audio> audios;

  final int startIndex;

  const Playlist({@required this.audios, this.startIndex = 0});

  int get numberOfItems => audios.length;
}
