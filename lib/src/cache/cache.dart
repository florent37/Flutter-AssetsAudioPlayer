import 'dart:async';

import 'package:assets_audio_player/src/playable.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

typedef CachePathProvider = Future<String> Function(Audio audio, String key);
typedef AudioKeyTransformer = Future<String> Function(Audio audio);

class AssetsAudioPlayerCache {
  final CachePathProvider cachePathProvider;
  final AudioKeyTransformer audioKeyTransformer;

  AssetsAudioPlayerCache(
      {@required this.cachePathProvider, @required this.audioKeyTransformer});
}

String removeHttpSpecialCharsFromStrings(String from) {
  return from
      .replaceAll(RegExp(r"/"), "_")
      .replaceAll(RegExp(r":"), "_")
      .replaceAll(RegExp(r"%"), "_");
}

AssetsAudioPlayerCache defaultAssetsAudioPlayerCache =
    AssetsAudioPlayerCache(cachePathProvider: (audio, key) async {
  final directory = await getTemporaryDirectory();
  final dirPath = directory.path;
  return '$dirPath/$key';
}, audioKeyTransformer: (audio) async {
  return removeHttpSpecialCharsFromStrings(audio.path);
});
