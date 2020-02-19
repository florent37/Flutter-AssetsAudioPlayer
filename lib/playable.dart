import 'package:flutter/foundation.dart';

class Playable {}

@immutable
class Audio implements Playable {
  final String path;

  const Audio(this.path);
}

@immutable
class Playlist implements Playable {
  final List<Audio> audios;

  final int startIndex;

  const Playlist({@required this.audios, this.startIndex = 0});

  int get numberOfItems => audios.length;
}