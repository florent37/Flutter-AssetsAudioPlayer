import 'dart:io';

import '../playable.dart';
import 'cache.dart';
import 'cache_downloader.dart';

AssetsAudioPlayerCacheManager _instance = AssetsAudioPlayerCacheManager._();

class AssetsAudioPlayerCacheManager {
  //singleton
  AssetsAudioPlayerCacheManager._();
  factory AssetsAudioPlayerCacheManager() => _instance;

  Map<String, CacheDownloader> _downloadingElements = Map();

  Future<Audio> transform(
    AssetsAudioPlayerCache cache,
    Audio audio,
    CacheDownloadListener cacheDownloadListener,
  ) async {
    if (audio.audioType != AudioType.network || audio.cached == false) {
      return audio;
    }

    final String key = await cache.audioKeyTransformer(audio);
    final String path = await cache.cachePathProvider(audio, key);
    if (await _fileExists(path)) {
      return audio.copyWith(path: path, audioType: AudioType.file);
    } else {
      try {
        await _download(audio, path, cacheDownloadListener);
        return audio.copyWith(path: path, audioType: AudioType.file);
      } catch (t) {
        //TODO
      }
    }

    return audio; //do not change anything if error
  }

  Future<bool> _fileExists(String path) async {
    final File file = File(path);
    return await file.exists();
  }

  Future<void> _download(
    Audio audio,
    String intoPath,
    CacheDownloadListener cacheDownloadListener,
  ) async {
    print(intoPath);
    if (_downloadingElements.containsKey(intoPath)) {
      //is already downloading it
      final downloader = _downloadingElements[intoPath];
      await downloader.wait(cacheDownloadListener);
    } else {
      try {
        final downloader = CacheDownloader();
        _downloadingElements[intoPath] = downloader;
        downloader.downloadAndSave(
          url: audio.path,
          savePath: intoPath,
          headers: audio.networkHeaders ?? {},
        );
        await downloader.wait(cacheDownloadListener);
        //download finished
        _downloadingElements.remove(intoPath);
      } catch (t) {
        //on error, remove also the downloader
        _downloadingElements.remove(intoPath);
        //then throw again the exception
        throw t;
      }
    }
  }
}
