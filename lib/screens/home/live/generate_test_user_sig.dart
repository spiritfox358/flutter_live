import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:archive/archive.dart';

/// ⚠️ 警告：此文件仅用于客户端本地测试跑通 TRTC！
/// ⚠️ 生产环境中，UserSig 必须由你的后端服务器计算并下发，切勿将 SDKSecretKey 保存在客户端！
class GenerateTestUserSig {
  // 你的腾讯云 SDKAppId
  static const int sdkAppId = 1600122692;
  // 你的腾讯云 SDKSecretKey
  static const String secretKey = "2abf6b0847dda0116e963663f4cb7f8fe94976271fae1a6df860df24744debfd";

  /// 计算标准的 UserSig 签名
  static String genTestSig(String userId) {
    int currTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    int expire = 604800; // 签名过期时间：7天

    // 1. 拼接明文
    String sigStr = "TLS.identifier:$userId\n"
        "TLS.sdkappid:$sdkAppId\n"
        "TLS.time:$currTime\n"
        "TLS.expire:$expire\n";

    // 2. HMAC-SHA256 签名
    List<int> msg = utf8.encode(sigStr);
    List<int> key = utf8.encode(secretKey);
    Hmac hmac = Hmac(sha256, key);
    Digest digest = hmac.convert(msg);
    String sig = base64.encode(digest.bytes);

    // 3. 构造 JSON 串
    Map<String, dynamic> sigDoc = {
      "TLS.ver": "2.0",
      "TLS.identifier": userId,
      "TLS.sdkappid": sdkAppId,
      "TLS.time": currTime,
      "TLS.expire": expire,
      "TLS.sig": sig,
    };
    String jsonStr = json.encode(sigDoc);

    // 4. 🚀 关键步骤：zlib 压缩
    List<int> compressed = ZLibEncoder().encode(utf8.encode(jsonStr));

    // 5. 🚀 关键步骤：Base64 编码，并按照腾讯云规范替换特殊字符
    String base64UrlSig = base64.encode(compressed)
        .replaceAll('+', '*')
        .replaceAll('/', '-')
        .replaceAll('=', '_');

    return base64UrlSig;
  }
}