import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/mission_response.dart';

/// ミッション関連の処理を担当するサービスクラス
class MissionService {
  // Firebase関連のインスタンス
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// Firebase Functions でAIミッションを生成
  Future<MissionResponse> generateMission({
    String? partnerUserId,  // ✅ オプショナルパラメータ
    String organizationId = 'default',
  }) async {
    try {
      // ✅ 認証確認
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('ユーザーがログインしていません');
      }

      if (kDebugMode) {
        debugPrint('🤖 AI ミッション生成開始 (Firebase Functions)');
        debugPrint('   - ユーザーID: ${currentUser.uid}');
        debugPrint('   - パートナーID: $partnerUserId');
      }

      // Firebase Functions呼び出し
      final HttpsCallable callable = _functions.httpsCallable('generateMission');

      // ✅ パートナーIDは任意（指定しない場合は自動選択）
      final result = await callable.call({
        if (partnerUserId != null) 'partnerUserId': partnerUserId,
      });

      final data = result.data as Map<String, dynamic>;

      return MissionResponse(
        missionText: data['mission']['text'] as String,
        isFallback: data['metadata']['isFallback'] == true,
        missionId: data['mission']['id'] as String,
        participants: List<String>.from(data['mission']['participants'] ?? []),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Firebase Functions ミッション生成エラー: $e');
      }

      // フォールバック処理
      return MissionResponse(
        missionText: _getRandomFallbackMission(),
        isFallback: true,
        missionId: 'fallback-${DateTime.now().millisecondsSinceEpoch}',
        participants: [],
      );
    }
  }

  /// ミッションフィードバックをFirestoreに送信
  ///
  /// [matchId] マッチングID
  /// [feedback] ユーザーが入力したフィードバック内容
  /// [partnerUserId] マッチした相手のユーザーID（オプション）
  Future<void> submitFeedback({
    required String matchId,
    required String feedback,
    String? partnerUserId,
    String? missionQuestion,
  }) async {
    try {
      // 現在のユーザー情報を取得
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('ユーザーがログインしていません');
      }

      // フィードバックが空でないかチェック
      if (feedback.trim().isEmpty) {
        throw Exception('フィードバックが入力されていません');
      }

      if (kDebugMode) {
        debugPrint('📝 ミッションフィードバック送信開始');
        debugPrint('   - ユーザーID: ${currentUser.uid}');
        debugPrint('   - マッチID: $matchId');
        debugPrint('   - フィードバック長: ${feedback.length}文字');
      }

      // ✅ 新方式でFirestoreに保存
    final docRef = await _firestore.collection('mission_results').add({
      // 新方式フィールド（今後のメイン）
      'fromUserId': currentUser.uid,      // 送信者
      'targetUserId': partnerUserId,      // 受信者
      'feedbackText': feedback.trim(),
      'missionQuestion': missionQuestion ?? 'ミッション内容不明',
      'fromUserName': '認証ユーザー',      // 後でユーザー名取得機能を追加
      'matchId': matchId,
      'organizationId': 'default',
      'submittedAt': Timestamp.now(),

      // 互換性のため旧方式フィールドも保持
      'userId': partnerUserId,            // 旧方式：受信者
      'submitterId': currentUser.uid,     // 旧方式：送信者
      'userIds': partnerUserId != null
          ? [currentUser.uid, partnerUserId]
          : [currentUser.uid],            // 旧方式：参加者配列
    });

      if (kDebugMode) {
        debugPrint('✅ ミッションフィードバック送信完了');
        debugPrint('   - ドキュメントID: ${docRef.id}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ ミッションフィードバック送信エラー: $e');
      }
      rethrow;
    }
  }

  /// フォールバックミッション（AI生成失敗時の定型ミッション）を取得
  String _getRandomFallbackMission() {
    final fallbackMissions = [
      'お互いの仕事で一番やりがいを感じる瞬間を教えあってください。',
      '最近ハマっていること・ものをプレゼンしあってください。',
      'もし1週間休みが取れたら、何をして過ごしたいか話し合ってください。',
      'お互いの部署の「あるある」を3つずつ紹介しあってください。',
      '今までで一番印象に残っている仕事の話をしてください。',
      'お互いのおすすめの本や映画を紹介しあってください。',
      '最近学んだことで興味深かったことを共有してください。',
      'もし転職するとしたら、どんな仕事に挑戦したいか話し合ってください。',
    ];

    // ランダムにフォールバックミッションを選択
    final randomIndex = DateTime.now().millisecondsSinceEpoch % fallbackMissions.length;
    final selectedMission = fallbackMissions[randomIndex];

    return selectedMission;
  }

  /// 特定のマッチに関するフィードバック履歴を取得
  ///
  /// [matchId] 取得したいマッチのID
  Future<List<Map<String, dynamic>>> getFeedbackHistory(String matchId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('ユーザーがログインしていません');
      }

      final querySnapshot = await _firestore
          .collection('mission_results')
          .where('matchId', isEqualTo: matchId)
          .where('userId', arrayContains: currentUser.uid)
          .orderBy('submittedAt', descending: true)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ フィードバック履歴取得エラー: $e');
      }
      rethrow;
    }
  }

  /// 現在のユーザーIDを取得
  String? getCurrentUserId() {
    return _auth.currentUser?.uid;
  }

  /// 現在のユーザーがログインしているかチェック
  bool isUserLoggedIn() {
    return _auth.currentUser != null;
  }

  /// テスト用: フォールバックミッションを直接取得
  MissionResponse getTestFallbackMission() {
    return MissionResponse(
      missionText: _getRandomFallbackMission(),
      isFallback: true,
      missionId: 'test-fallback-${DateTime.now().millisecondsSinceEpoch}',
      generatedAt: DateTime.now(),
      participants: [],
    );
  }
}
