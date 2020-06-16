import 'package:dio/dio.dart';
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

class CacheDownloader {

  final Dio dio;

  CacheDownloader({@required this.dio});

  final List<Completer> _waiters = [];

  void downloadAndSave({
    String url,
    String savePath,
    Map<String, dynamic> headers,
    Function(int received, int total) progressFunction,
  }) async {

    //1. download

    try {
      final Response response = await dio.get(
        url,
        onReceiveProgress: progressFunction,
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
        waiter.complete();
      }
      _waiters.clear();
    } catch (t){
      for (var waiter in _waiters) {
        waiter.completeError(t);
      }
    }
  }

  Future<String> wait() async {
    Completer waiter = Completer();
    this._waiters.add(waiter);
    return await waiter.future;
  }

}