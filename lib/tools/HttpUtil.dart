import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class HttpUtil {
  // 单例模式
  static final HttpUtil _instance = HttpUtil._internal();
  factory HttpUtil() => _instance;

  late Dio _dio;

  // 🟢 关键配置：后端地址
  // 如果是 Android 模拟器，使用 10.0.2.2
  // 如果是 真机调试，使用你电脑的局域网 IP (例如 192.168.1.5)
  // 端口要和你 Spring Boot 的 server.port 保持一致 (我看你之前截图是 8358)
  static const String _baseUrl = 'http://192.168.1.214:8358';

  HttpUtil._internal() {
    BaseOptions options = BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
      headers: {},
      contentType: Headers.jsonContentType,
      responseType: ResponseType.json,
    );

    _dio = Dio(options);

    // 添加拦截器 (打印日志，方便调试)
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        debugPrint("请求发送: ${options.method} ${options.uri}");
        return handler.next(options);
      },
      onResponse: (response, handler) {
        debugPrint("请求响应: ${response.statusCode} ${response.data}");
        return handler.next(response);
      },
      onError: (DioException e, handler) {
        debugPrint("请求出错: ${e.message}");
        return handler.next(e);
      },
    ));
  }

  // GET 请求
  Future<dynamic> get(String path, {Map<String, dynamic>? params}) async {
    try {
      Response response = await _dio.get(path, queryParameters: params);
      return _handleResponse(response);
    } catch (e) {
      rethrow;
    }
  }

  // POST 请求
  Future<dynamic> post(String path, {dynamic data}) async {
    try {
      Response response = await _dio.post(path, data: data);
      return _handleResponse(response);
    } catch (e) {
      rethrow;
    }
  }

  // 统一处理后端返回的 Result 结构
  dynamic _handleResponse(Response response) {
    if (response.statusCode == 200) {
      // 假设后端返回结构: { "code": 200, "msg": "成功", "data": ... }
      final result = response.data;
      if (result['code'] == 200) {
        return result['data']; // 只返回 data 部分
      } else {
        throw Exception(result['msg'] ?? "请求失败");
      }
    } else {
      throw Exception("网络异常: ${response.statusCode}");
    }
  }
}