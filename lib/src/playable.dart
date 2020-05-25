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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MetasImage &&
          runtimeType == other.runtimeType &&
          path == other.path &&
          package == other.package &&
          type == other.type;

  @override
  int get hashCode => path.hashCode ^ package.hashCode ^ type.hashCode;
}

@immutable
class Metas {
  final String title;
  final String artist;
  final String album;
  final Map<String, dynamic> extra;
  final MetasImage image;

  const Metas({
    this.title,
    this.artist,
    this.album,
    this.image,
    this.extra,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Metas &&
          runtimeType == other.runtimeType &&
          title == other.title &&
          artist == other.artist &&
          album == other.album &&
          image == other.image;

  @override
  int get hashCode =>
      title.hashCode ^ artist.hashCode ^ album.hashCode ^ image.hashCode;
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Audio &&
          runtimeType == other.runtimeType &&
          path == other.path &&
          package == other.package &&
          audioType == other.audioType &&
          metas == other.metas;

  @override
  int get hashCode =>
      path.hashCode ^ package.hashCode ^ audioType.hashCode ^ metas.hashCode;
}

class Playlist implements Playable {
  final List<Audio> audios = [];

  final int startIndex;

  Playlist({List<Audio> audios, this.startIndex = 0}) {
    if(audios != null) {
      this.audios.addAll(audios);
    }
  }

  int get numberOfItems => audios.length;

  Playlist add(Audio audio) {
    if(audio != null) {
      this.audios.add(audio);
    }
    return this;
  }

  Playlist addAll(List<Audio> audios) {
    if(audios != null) {
      this.audios.addAll(audios);
    }
    return this;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Playlist &&
          runtimeType == other.runtimeType &&
          audios == other.audios &&
          startIndex == other.startIndex;

  @override
  int get hashCode => audios.hashCode ^ startIndex.hashCode;
}
