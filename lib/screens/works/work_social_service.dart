import '../../tools/HttpUtil.dart';

class WorkSocialService {
  static Future<Map<String, dynamic>> likeWork(int workId) async {
    final data = await HttpUtil().post('/api/work/$workId/like');
    return Map<String, dynamic>.from(data as Map);
  }

  static Future<Map<String, dynamic>> unlikeWork(int workId) async {
    final data = await HttpUtil().delete('/api/work/$workId/like');
    return Map<String, dynamic>.from(data as Map);
  }

  static Future<List<Map<String, dynamic>>> getComments(
    int workId, {
    int cursor = 0,
    int limit = 20,
  }) async {
    final data = await HttpUtil().get(
      '/api/work/$workId/comments',
      params: {'cursor': cursor, 'limit': limit},
    );
    return (data as List<dynamic>? ?? [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  static Future<Map<String, dynamic>> createComment(
    int workId,
    String content, {
    int? parentId,
    int? replyToUserId,
  }) async {
    final payload = <String, dynamic>{'content': content};
    if (parentId != null) payload['parentId'] = parentId;
    if (replyToUserId != null) payload['replyToUserId'] = replyToUserId;

    final data = await HttpUtil().post(
      '/api/work/$workId/comments',
      data: payload,
    );
    return Map<String, dynamic>.from(data as Map);
  }
}
