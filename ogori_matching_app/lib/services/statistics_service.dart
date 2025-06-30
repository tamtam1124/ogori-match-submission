import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class StatisticsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // マッチング統計を取得（デバッグ情報付き）
  Future<MatchingStatistics> getMatchingStatistics() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        if (kDebugMode) {
          debugPrint('⚠️ ユーザーがログインしていません');
        }
        return MatchingStatistics(
          totalMatches: 0,
          monthlyMatches: 0,
          newConnections: 0,
          successfulCollaborations: 0,
        );
      }

      if (kDebugMode) {
        debugPrint('📊 統計データ取得開始 - User ID: ${user.uid}');
      }

      // 今月の開始日
      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1);
      final monthStartTimestamp = Timestamp.fromDate(monthStart);

      if (kDebugMode) {
        debugPrint('📅 今月の開始日: $monthStart');
      }

      // 全体のマッチング数を取得
      final totalMatchesQuery = await _firestore
          .collection('matches')
          .where('participants', arrayContains: user.uid)
          .where('status', isEqualTo: 'success')
          .get();

      if (kDebugMode) {
        debugPrint('🎯 総マッチング数クエリ結果: ${totalMatchesQuery.docs.length}件');
        for (var doc in totalMatchesQuery.docs) {
          debugPrint('  - Match ID: ${doc.id}, Data: ${doc.data()}');
        }
      }

      // 今月のマッチング数を取得
      final monthlyMatchesQuery = await _firestore
          .collection('matches')
          .where('participants', arrayContains: user.uid)
          .where('status', isEqualTo: 'success')
          .where('createdAt', isGreaterThanOrEqualTo: monthStartTimestamp)
          .get();

      if (kDebugMode) {
        debugPrint('📈 今月のマッチング数: ${monthlyMatchesQuery.docs.length}件');
      }

      // 新しいつながり（ユニークなユーザー数）
      final allMatches = totalMatchesQuery.docs;
      final uniqueConnections = <String>{};

      for (var doc in allMatches) {
        final participants = List<String>.from(doc.data()['participants'] ?? []);
        for (var participant in participants) {
          if (participant != user.uid) {
            uniqueConnections.add(participant);
          }
        }
      }

      if (kDebugMode) {
        debugPrint('🤝 ユニークなつながり: ${uniqueConnections.length}人');
        debugPrint('  - 接続ユーザー: $uniqueConnections');
      }

      // 成功したコラボレーション数
      final collaborationsQuery = await _firestore
          .collection('collaborations')
          .where('participants', arrayContains: user.uid)
          .where('status', isEqualTo: 'completed')
          .get();

      if (kDebugMode) {
        debugPrint('💼 コラボレーション数: ${collaborationsQuery.docs.length}件');
      }

      // 全体的なデータベース状態をチェック
      final allMatchesInDB = await _firestore.collection('matches').get();
      final allCollaborationsInDB = await _firestore.collection('collaborations').get();
      final allUsersInDB = await _firestore.collection('users').get();

      if (kDebugMode) {
        debugPrint('🗄️ データベース全体状態:');
        debugPrint('  - 全マッチング: ${allMatchesInDB.docs.length}件');
        debugPrint('  - 全コラボレーション: ${allCollaborationsInDB.docs.length}件');
        debugPrint('  - 全ユーザー: ${allUsersInDB.docs.length}件');
      }

      final result = MatchingStatistics(
        totalMatches: totalMatchesQuery.docs.length,
        monthlyMatches: monthlyMatchesQuery.docs.length,
        newConnections: uniqueConnections.length,
        successfulCollaborations: collaborationsQuery.docs.length,
      );

      if (kDebugMode) {
        debugPrint('✅ 統計結果: ${result.toString()}');
      }

      return result;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 統計取得エラー: $e');
      }
      return MatchingStatistics(
        totalMatches: 0,
        monthlyMatches: 0,
        newConnections: 0,
        successfulCollaborations: 0,
      );
    }
  }

  // テスト用のダミーデータ作成
  Future<void> createTestData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      if (kDebugMode) {
        debugPrint('🧪 テストデータ作成開始...');
      }

      // テスト用マッチングデータを3件作成
      for (int i = 1; i <= 3; i++) {
        await _firestore.collection('matches').add({
          'participants': [user.uid, 'test_user_$i'],
          'status': 'success',
          'createdAt': Timestamp.now(),
          'updatedAt': Timestamp.now(),
        });

        if (kDebugMode) {
          debugPrint('  ✅ マッチング$i作成完了');
        }
      }

      // テスト用コラボレーションデータを2件作成
      for (int i = 1; i <= 2; i++) {
        await _firestore.collection('collaborations').add({
          'participants': [user.uid, 'test_user_$i'],
          'status': 'completed',
          'description': 'テストプロジェクト$i',
          'createdAt': Timestamp.now(),
          'completedAt': Timestamp.now(),
        });

        if (kDebugMode) {
          debugPrint('  ✅ コラボレーション$i作成完了');
        }
      }

      if (kDebugMode) {
        debugPrint('🎉 テストデータ作成完了！');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ テストデータ作成エラー: $e');
      }
    }
  }

  // マッチング成功時に記録
  Future<void> recordMatchSuccess(String partnerUid) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      if (kDebugMode) {
        debugPrint('📝 マッチング記録開始: ${user.uid} <-> $partnerUid');
      }

      await _firestore.collection('matches').add({
        'participants': [user.uid, partnerUid],
        'status': 'success',
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });

      if (kDebugMode) {
        debugPrint('✅ マッチング記録完了');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ マッチング記録エラー: $e');
      }
    }
  }

  // コラボレーション完了時に記録
  Future<void> recordCollaborationSuccess(String partnerUid, String description) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _firestore.collection('collaborations').add({
        'participants': [user.uid, partnerUid],
        'status': 'completed',
        'description': description,
        'createdAt': Timestamp.now(),
        'completedAt': Timestamp.now(),
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ コラボレーション記録エラー: $e');
      }
    }
  }

  // リアルタイム統計ストリーム
  Stream<MatchingStatistics> watchMatchingStatistics() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value(MatchingStatistics(
        totalMatches: 0,
        monthlyMatches: 0,
        newConnections: 0,
        successfulCollaborations: 0,
      ));
    }

    return _firestore
        .collection('matches')
        .where('participants', arrayContains: user.uid)
        .snapshots()
        .asyncMap((snapshot) async {
      return await getMatchingStatistics();
    });
  }
}

// 統計データクラス（toString追加）
class MatchingStatistics {
  final int totalMatches;
  final int monthlyMatches;
  final int newConnections;
  final int successfulCollaborations;

  MatchingStatistics({
    required this.totalMatches,
    required this.monthlyMatches,
    required this.newConnections,
    required this.successfulCollaborations,
  });

  @override
  String toString() {
    return 'MatchingStatistics(total: $totalMatches, monthly: $monthlyMatches, connections: $newConnections, collaborations: $successfulCollaborations)';
  }
}
