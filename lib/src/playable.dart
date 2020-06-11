import 'package:assets_audio_player/assets_audio_player.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

class Playable {}

enum AudioType {
  network,
  liveStream,
  file,
  asset,
}

String audioTypeDescription(AudioType audioType) {
  switch (audioType) {
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

enum ImageType {
  network,
  file,
  asset,
}

String imageTypeDescription(ImageType imageType) {
  switch (imageType) {
    case ImageType.network:
      return "network";
    case ImageType.file:
      return "file";
    case ImageType.asset:
      return "asset";
  }
  return null;
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

class Metas {
  String id;
  final String title;
  final String artist;
  final String album;
  final Map<String, dynamic> extra;
  final MetasImage image;

  Metas({
    this.id,
    this.title,
    this.artist,
    this.album,
    this.image,
    this.extra,
  }) {
    if (this.id == null) {
      this.id = Uuid().v4();
    }
  }

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

  Metas copyWith({
    String id,
    String title,
    String artist,
    String album,
    Map<String, dynamic> extra,
    MetasImage image,
  }) {
    return new Metas(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      extra: extra ?? this.extra,
      image: image ?? this.image,
    );
  }
}

class Audio implements Playable {
  final String path;
  final String package;
  final AudioType audioType;
  Metas _metas;
  Map _networkHeaders;

  Metas get metas => _metas;
  Map get networkHeaders => _networkHeaders;

  Audio._({
    this.path,
    this.package,
    this.audioType,
    Map headers,
    Metas metas,
  })  : _metas = metas,
        _networkHeaders = headers;

  Audio(this.path, {Metas metas, this.package})
      : audioType = AudioType.asset,
        _networkHeaders = null,
        _metas = metas;

  Audio.file(this.path, {Metas metas})
      : audioType = AudioType.file,
        package = null,
        _networkHeaders = null,
        _metas = metas;

  Audio.network(this.path, {Metas metas, Map headers})
      : audioType = AudioType.network,
        package = null,
        _networkHeaders = headers,
        _metas = metas;

  Audio.liveStream(this.path, {Metas metas, Map headers})
      : audioType = AudioType.liveStream,
        package = null,
        _networkHeaders = headers,
        _metas = metas;

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

  @override
  String toString() {
    return 'Audio{path: $path, package: $package, audioType: $audioType, _metas: $_metas, _networkHeaders: $_networkHeaders}';
  }

  void updateMetas({
    AssetsAudioPlayer player,
    String title,
    String artist,
    String album,
    Map<String, dynamic> extra,
    MetasImage image,
  }) {
    this._metas = (_metas ?? Metas()).copyWith(
      title: title,
      artist: artist,
      album: album,
      extra: extra,
      image: image,
    );
    if (player != null) {
      player.onAudioUpdated(this);
    }
  }

  Audio copyWith({
    String path,
    String package,
    AudioType audioType,
    Metas metas,
    Map headers,
  }) {
    return Audio._(
      path: path ?? this.path,
      package: package ?? this.package,
      audioType: audioType ?? this.audioType,
      metas: metas ?? this._metas,
      headers: headers ?? this._networkHeaders,
    );
  }
}

class Playlist implements Playable {
  final List<Audio> audios = [];

  int _startIndex = 0;
  int get startIndex => _startIndex;
  set startIndex(int newValue) {
    if (newValue < this.audios.length) {
      _startIndex = newValue;
    }
  }

  Playlist({List<Audio> audios, int startIndex = 0}) {
    if (audios != null) {
      this.audios.addAll(audios);
    }
    this.startIndex = startIndex;
  }

  int get numberOfItems => audios.length;

  Playlist add(Audio audio) {
    if (audio != null) {
      this.audios.add(audio);
    }
    return this;
  }

  Playlist insert(int index, Audio audio) {
    if (audio != null) {
      this.audios.insert(index, audio );
    }
    //here maybe stop/open the new song if playing this index
    return this;
  }

  Playlist addAll(List<Audio> audios) {
    if (audios != null) {
      this.audios.addAll(audios);
    }
    return this;
  }

  bool remove(Audio audio){
    if(audio == null)
      return false;
    final bool removed = this.audios.remove(audio);
    //here maybe stop the player if playing this index
    return removed;
  }

  Audio removeAtIndex(int index){
    Audio removedAudio = this.audios.removeAt(index);
    //here maybe stop the player if playing this index
    return removedAudio;
  }

  bool contains(Audio audio){
    return this.audios.contains(audio);
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

void writeAudioMetasInto(
    Map<String, dynamic> params, /* nullable */ Metas metas) {
  if (metas != null) {
    if (metas.title != null) params["song.title"] = metas.title;
    if (metas.artist != null) params["song.artist"] = metas.artist;
    if (metas.album != null) params["song.album"] = metas.album;
    if (metas.image != null) {
      params["song.image"] = metas.image.path;
      params["song.imageType"] = imageTypeDescription(metas.image.type);
      if (metas.image.package != null)
        params["song.imagePackage"] = metas.image.package;
    }
    if (metas.id != null) {
      params["song.trackID"] = metas.id;
    }
  }
}

class PlayerGroupMetas {
  final String title;
  final String subTitle;
  final MetasImage image;

  PlayerGroupMetas({
    this.title,
    this.subTitle,
    this.image,
  });
}
