import 'package:dio/dio.dart';
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

class CacheDownloadInfos {
  final int received;
  final int total;

  const CacheDownloadInfos({
    @required this.received,
    @required this.total,
  });

  double get percent {
    if(total == 0) return 0;
    else return received / total;
  }

}

typedef CacheDownloadListener = Function(CacheDownloadInfos infos);

class _DownloadWaiter {
  final Completer completer = Completer();
  final CacheDownloadListener downloadInfosListener;

  _DownloadWaiter({this.downloadInfosListener});

  void pingInfos(CacheDownloadInfos infos) {
    if(downloadInfosListener != null){
      downloadInfosListener(infos);
    }
  }
}

class CacheDownloader {

  final Dio dio;

  CacheDownloader({@required this.dio});

  final List<_DownloadWaiter> _waiters = [];

  void _dispose(){
    _waiters.clear();
  }

  Future<void> downloadAndSave({
    String url,
    String savePath,
    Map<String, dynamic> headers,
  }) async {

    //1. download

    try {
      final Response response = await dio.get(
        url,
        onReceiveProgress: (received, total){
          final infos =  CacheDownloadInfos(
              received: received,
              total: total
          );
          for (var waiter in _waiters) {
            waiter.pingInfos(infos);
          }
        },
        //Received data with List<int>
        options: Options(
            headers: headers,
            responseType: ResponseType.bytes,
            followRedirects: false,
            validateStatus: (status) {
              return status < 500;
            }),
      );

      //save file
      final File file = File(savePath);
      var raf = file.openSync(mode: FileMode.write);
      // response.data is List<int> type
      raf.writeFromSync(response.data);

      await raf.close();

      for (var waiter in _waiters) {
        waiter.completer.complete();
      }
      _dispose();
    } catch (t){
      for (var waiter in _waiters) {
        waiter.completer.completeError(t);
      }
      _dispose();
    }
  }

  Future<String> wait(CacheDownloadListener downloadListener) async {
    final waiter = _DownloadWaiter(downloadInfosListener: downloadListener);
    this._waiters.add(waiter);
    return await waiter.completer.future;
  }

}