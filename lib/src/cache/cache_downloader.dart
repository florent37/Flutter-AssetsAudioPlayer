import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class CacheDownloadInfos {
  const CacheDownloadInfos({
    @required this.received,
    @required this.total,
  });

  final int received;
  final int total;

  double get percent {
    if (total == 0)
      return 0;
    else
      return received / total;
  }
}

typedef CacheDownloadListener = Function(CacheDownloadInfos infos);

class _DownloadWaiter {
  _DownloadWaiter({this.downloadInfosListener});

  final Completer completer = Completer();
  final CacheDownloadListener downloadInfosListener;

  void pingInfos(CacheDownloadInfos infos) {
    if (downloadInfosListener != null) {
      downloadInfosListener(infos);
    }
  }
}

class CacheDownloader {
  final List<_DownloadWaiter> _waiters = [];

  void _dispose() {
    _waiters.clear();
  }

  Future<void> downloadAndSave({
    String url,
    String savePath,
    Map<String, dynamic> headers,
  }) async {
    final http.Client client = http.Client();
    final uri = Uri.parse(url);
    final http.Request request = http.Request('GET', uri);

    if (headers != null && !headers.isEmpty) {
      request.headers.addAll(headers);
    }

    request.followRedirects = false;

    final Future<http.StreamedResponse> response = client.send(request);

    final File file = File(savePath);
    final RandomAccessFile raf = file.openSync(mode: FileMode.write);
    final List<List<int>> responseChunk = <List<int>>[];
    int downloadedLength = 0;

    final Completer completer = Completer();
    response.asStream().listen((http.StreamedResponse r) {
      r.stream.listen((List<int> chunk) {
        raf.writeFromSync(chunk);
        responseChunk.add(chunk);
        downloadedLength += chunk.length;
        final CacheDownloadInfos infos = CacheDownloadInfos(
          received: downloadedLength,
          total: r.contentLength,
        );
        for (final _DownloadWaiter waiter in _waiters) {
          waiter.pingInfos(infos);
        }
      }, onDone: () async {
        await raf.close();

        for (final _DownloadWaiter waiter in _waiters) {
          waiter.completer.complete();
        }
        _dispose();

        completer.complete();
      }, onError: (dynamic e) {
        for (final _DownloadWaiter waiter in _waiters) {
          waiter.completer.completeError(e);
        }
        _dispose();
        completer.completeError(e);
      });
    });

    await completer.future;
  }

  Future<String> wait(CacheDownloadListener downloadListener) async {
    final waiter = _DownloadWaiter(downloadInfosListener: downloadListener);
    this._waiters.add(waiter);
    return await waiter.completer.future;
  }
}
