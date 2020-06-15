import 'package:assets_audio_player/src/playable.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

typedef CachePathProvider = Future<String> Function(Audio audio);

class AssetsAudioPlayerCache {
  final CachePathProvider cachePathProvider;

  AssetsAudioPlayerCache({@required this.cachePathProvider});
}

AssetsAudioPlayerCache defaultAssetsAudioPlayerCache = AssetsAudioPlayerCache(
    cachePathProvider: (audio) async {
      final String fileName = audio.path; //TODO replace special chars
      final dir = (await getTemporaryDirectory()).path;
      return '$dir/$fileName';
    }
);