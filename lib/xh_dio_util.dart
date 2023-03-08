library flutter_pub_dio_util;

import 'package:dio/dio.dart';
import 'dart:convert';

/// 请求方法
enum DioMethod {
  get,
  post,
  put,
  delete,
  patch,
  head,
}

const _methodValues = {
  DioMethod.get: 'get',
  DioMethod.post: 'post',
  DioMethod.put: 'put',
  DioMethod.delete: 'delete',
  DioMethod.patch: 'patch',
  DioMethod.head: 'head'
};

class XHDioUtil {
  static const String _tag = 'DioUtil';

  static Map dioMap = <String, XHDioUtil>{};

  /// 连接超时时间
  static Duration connectTimeout = const Duration(seconds: 8);

  /// 响应超时时间
  static Duration receiveTimeout = const Duration(seconds: 30);

  Map<String, dynamic>? commonHeaders;

  var isOpenLog = false;

  /// Dio实例
  Dio? _dio;
  late BaseOptions baseoptions;
  static String? _baseUrl;

  dynamic _expiredHandle;
  int? _expiredCode;

  void _printLog(String log) {
    if (isOpenLog) {
      print('$_tag ' + log);
    }
  }

  void setExpiredWork(int expiredCode, dynamic expiredWork) {
    _expiredHandle = expiredWork;
    _expiredCode = expiredCode;
  }

  static XHDioUtil getDioUtil(String key) {
    return dioMap[key];
  }

  //设置连接超时时间 @duration
  void setConnectMaxTime(Duration duration) {
    connectTimeout = duration;
  }

  //设置接受数据超时时间
  void setReceiveMaxTime(Duration duration) {
    receiveTimeout = duration;
  }

  //设置BaseUrl
  void setBaseUrl(String baseUrl) {
    if (baseUrl.isEmpty || Uri.parse(baseUrl).host.isEmpty) {
      _printLog('setBaseUrl Error : url is not a host');
      return;
    }

    _baseUrl = baseUrl;
    if (_dio != null) {
      _dio?.options.baseUrl = baseUrl;
    }
  }

  /// 开启日志打印
  void openLog() {
    isOpenLog = true;
    _dio?.interceptors
        .add(LogInterceptor(responseHeader: false, responseBody: true));
  }

  /// 初始化
  XHDioUtil build({String? key}) {
    _initDio();
    _dio?.interceptors
        .add(LogInterceptor(responseHeader: false, responseBody: true));

    _dio?.interceptors.add(
      InterceptorsWrapper(
        onRequest: (RequestOptions options, RequestInterceptorHandler handler) {
          // 如果你想完成请求并返回一些自定义数据，你可以使用 `handler.resolve(response)`。
          // 如果你想终止请求并触发一个错误,你可以使用 `handler.reject(error)`。

          _printLog('onRequest');
          return handler.next(options);
        },
        onResponse: (response, handler) {
          // 如果你想终止请求并触发一个错误,你可以使用 `handler.reject(error)`。

          if (_expiredHandle != null && response.statusCode == _expiredCode) {
            //请求过期，调用应用层给出的过期处理方法
            _expiredHandle();
            handler.reject(DioError(
                requestOptions: response.requestOptions, message: 'Expired'));
            return;
          }
          _printLog('onResponse');
          return handler.next(response);
        },
        onError: (e, handler) {
          // 如果你想完成请求并返回一些自定义数据，你可以使用 `handler.resolve(response)`。
          _printLog('onError');
          return handler.next(e);
        },
      ),
    );

    if (key != null) {
      dioMap[key] = this;
    }

    return this;
  }

  // 初始化dio
  void _initDio() {
    try {
      baseoptions = BaseOptions(
          baseUrl: _baseUrl ?? '',
          headers: commonHeaders,
          responseType: ResponseType.plain,
          connectTimeout: connectTimeout,
          receiveTimeout: receiveTimeout);

      _dio = Dio(baseoptions);
    } catch (e) {
      _printLog('initDio Error :' + e.toString());
      _dio = Dio(BaseOptions(
          responseType: ResponseType.plain,
          connectTimeout: connectTimeout,
          receiveTimeout: receiveTimeout));
    }
  }

  /// 请求类
  Future<T> request<T>(String path,
      {DioMethod method = DioMethod.get,
      Map<String, dynamic>? params,
      data,
      CancelToken? cancelToken,
      Options? options,
      ProgressCallback? onSendProgress,
      ProgressCallback? onReceiveProgress,
      dynamic? beanFromJson}) async {
    if (_dio == null) {
      _printLog('DioUtil must build first');
    }
    options ??= Options(method: _methodValues[method]);
    try {
      Response response;
      response = await _dio!.request(path,
          data: data,
          queryParameters: params,
          cancelToken: cancelToken,
          options: options,
          onSendProgress: onSendProgress,
          onReceiveProgress: onReceiveProgress);
      if (beanFromJson != null) {
        Map dataMap = json.decode(response.data.toString());
        dynamic resultBean = beanFromJson(dataMap);
        return resultBean;
      }

      return response.data;
    } on DioError catch (e) {
      _printLog('DioError: $e');
      rethrow;
    } catch (e) {
      _printLog('catch: $e');
      rethrow;
    }
  }
}
