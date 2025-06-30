import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import 'dart:async';

class MatchingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  // ✨ Firebase Functionsを使ったマッチング処理
  Future<MatchingResult> processMatching() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        if (kDebugMode) {
          debugPrint('❌ ユーザーがログインしていません');
        }
        throw Exception('ユーザーがログインしていません');
      }

      if (kDebugMode) {
        debugPrint('🎯 Firebase Functionsでマッチング処理開始');
      }

      // Firebase FunctionsのprocessMatching関数を呼び出し
      final result = await _functions
          .httpsCallable('processMatching')
          .call();

      final data = result.data as Map<String, dynamic>;

      if (data['success'] == true) {
        if (data['matched'] == true) {
          // マッチング成立
          final partnerData = data['partner'] as Map<String, dynamic>;
          final partner = UserModel.fromMap(partnerData);

          if (kDebugMode) {
            debugPrint('✅ マッチング成立: ${partner.displayName}');
          }

          return MatchingResult.success(
            partner: partner,
            matchId: data['matchId'],
          );
        } else {
          // 待機キューに追加
          if (kDebugMode) {
            debugPrint('⏳ 待機キューに追加: ${data['queueId']}');
          }

          return MatchingResult.waiting(
            queueId: data['queueId'],
            waitingCount: data['waitingCount'] ?? 0,
          );
        }
      } else {
        throw Exception('マッチング処理が失敗しました');
      }

    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ マッチング処理エラー: $e');
      }
      throw Exception('マッチング処理でエラーが発生しました: $e');
    }
  }

  // ✨ Firebase Functionsを使ったマッチングキャンセル
  Future<void> cancelMatching({String? queueId}) async {
    try {
      if (kDebugMode) {
        debugPrint('🚪 マッチングキャンセル開始');
      }

      await _functions
          .httpsCallable('cancelMatching')
          .call({'queueId': queueId});

      if (kDebugMode) {
        debugPrint('✅ マッチングキャンセル完了');
      }

    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ マッチングキャンセルエラー: $e');
      }
      throw Exception('キャンセル処理でエラーが発生しました: $e');
    }
  }

  // ✨ リアルタイム監視（既存の機能を維持）
  Stream<DocumentSnapshot> watchMyQueueStatus(String queueId) {
    return _firestore
        .collection('matching_queue')
        .doc(queueId)
        .snapshots();
  }

  // ✨ 追加: マッチした相手のプロフィールを取得
  Future<UserModel?> getMatchedPartner(String partnerId) async {
    try {
      final partnerDoc = await _firestore
          .collection('users')
          .doc(partnerId)
          .get();

      if (partnerDoc.exists) {
        final data = partnerDoc.data() as Map<String, dynamic>;
        return UserModel.fromMap({
          'uid': partnerId,
          ...data,
        });
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ パートナープロフィール取得エラー: $e');
      }
      return null;
    }
  }

  // ✨ 追加: 監視停止メソッド（互換性のため）
  void stopWatching() {
    // このメソッドは画面側でStreamSubscriptionを管理するため、
    // 実際の処理は何もしないが、既存コードとの互換性のために提供
    if (kDebugMode) {
      debugPrint('🛑 監視停止（画面側でStreamSubscription管理）');
    }
  }

  // 既存のメソッドは互換性のため残す（内部的にはprocessMatchingを使用）
  @Deprecated('Use processMatching() instead')
  Future<String?> joinMatchingQueue() async {
    try {
      final result = await processMatching();
      if (result.isWaiting) {
        return result.queueId;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  @Deprecated('Use processMatching() instead')
  Future<UserModel?> findWaitingUser(String myQueueId) async {
    try {
      final result = await processMatching();
      if (result.isMatched) {
        return result.partner;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  @Deprecated('Use cancelMatching() instead')
  Future<void> leaveMatchingQueue(String queueId) async {
    await cancelMatching(queueId: queueId);
  }

  // その他の既存メソッドはそのまま維持
  Future<void> recordMatch(String partnerUid) async {
    // この処理はすでにFunctions側で行われるため、空実装
    if (kDebugMode) {
      debugPrint('📝 マッチング記録は Functions 側で処理済み');
    }
  }

  Future<int> getWaitingUsersCount() async {
    try {
      final waitingQuery = await _firestore
          .collection('matching_queue')
          .where('status', isEqualTo: 'waiting')
          .get();
      return waitingQuery.docs.length;
    } catch (e) {
      return 0;
    }
  }

  // デバッグ用：キューの状態を確認
  Future<void> debugQueueStatus() async {
    try {
      final allQueues = await _firestore
          .collection('matching_queue')
          .get();

      if (kDebugMode) {
        debugPrint('=== キュー状態確認 ===');
        for (final doc in allQueues.docs) {
          final data = doc.data();
          debugPrint('ID: ${doc.id}, Status: ${data['status']}, User: ${data['userId']}');
        }
        debugPrint('===================');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ キュー状態確認エラー: $e');
      }
    }
  }
}

// ✨ マッチング結果を表すクラス
class MatchingResult {
  final bool isMatched;
  final bool isWaiting;
  final UserModel? partner;
  final String? matchId;
  final String? queueId;
  final int waitingCount;

  MatchingResult._({
    required this.isMatched,
    required this.isWaiting,
    this.partner,
    this.matchId,
    this.queueId,
    this.waitingCount = 0,
  });

  factory MatchingResult.success({
    required UserModel partner,
    required String matchId,
  }) {
    return MatchingResult._(
      isMatched: true,
      isWaiting: false,
      partner: partner,
      matchId: matchId,
    );
  }

  factory MatchingResult.waiting({
    required String queueId,
    required int waitingCount,
  }) {
    return MatchingResult._(
      isMatched: false,
      isWaiting: true,
      queueId: queueId,
      waitingCount: waitingCount,
    );
  }
}
