// lib/models/feedback_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class FeedbackData {
  final String id;
  final String fromUserId;      // 送信者ID
  final String targetUserId;    // 受信者ID
  final String feedbackText;
  final String missionQuestion;
  final String fromUserName;    // 送信者名
  final DateTime createdAt;
  final String matchId;
  final String organizationId;

  FeedbackData({
    required this.id,
    required this.fromUserId,
    required this.targetUserId,
    required this.feedbackText,
    required this.missionQuestion,
    required this.fromUserName,
    required this.createdAt,
    required this.matchId,
    required this.organizationId,
  });

  // ✅ 新旧両方式に対応したファクトリーメソッド
  factory FeedbackData.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data();
    if (data == null) {
      throw StateError('Snapshot data was null!');
    }

    return FeedbackData(
      id: snapshot.id,
      // 新旧両方式に対応
      fromUserId: data['fromUserId'] ?? data['submitterId'] ?? '',
      targetUserId: data['targetUserId'] ?? data['userId'] ?? '',
      feedbackText: data['feedbackText'] ?? '',
      missionQuestion: data['missionQuestion'] ?? 'ミッション内容不明',
      fromUserName: data['fromUserName'] ?? data['submitterName'] ?? '匿名',
      createdAt: (data['submittedAt'] as Timestamp?)?.toDate() ??
                 (data['createdAt'] as Timestamp?)?.toDate() ??
                 DateTime.now(),
      matchId: data['matchId'] ?? '',
      organizationId: data['organizationId'] ?? 'default',
    );
  }
}
