import 'package:cloud_firestore/cloud_firestore.dart';

class AIProfileData {
  final String userId;
  final String comprehensivePersonality;  // 1. 総合的な人物像
  final String futurePreview;            // 2. ヨコク（予告）
  final List<String> keywordsList;       // 3. キーワード5つ
  final Timestamp createdAt;
  final Timestamp updatedAt;

  AIProfileData({
    required this.userId,
    required this.comprehensivePersonality,
    required this.futurePreview,
    required this.keywordsList,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'comprehensivePersonality': comprehensivePersonality,
      'futurePreview': futurePreview,
      'keywordsList': keywordsList,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory AIProfileData.fromFirestore(Map<String, dynamic> data, String id) {
    return AIProfileData(
      userId: data['userId'] ?? '',
      comprehensivePersonality: data['comprehensivePersonality'] ?? '',
      futurePreview: data['futurePreview'] ?? '',
      keywordsList: List<String>.from(data['keywordsList'] ?? []),
      createdAt: data['createdAt'] ?? Timestamp.now(),
      updatedAt: data['updatedAt'] ?? Timestamp.now(),
    );
  }
}
