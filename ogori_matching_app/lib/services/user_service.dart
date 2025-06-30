import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../models/feedback_model.dart';
import '../models/ai_profile_model.dart';
import 'package:cloud_functions/cloud_functions.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  // 初期プロフィールの作成
  Future<void> createInitialProfile(User user) async {
    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();

      if (!doc.exists) {
        final userModel = UserModel(
          uid: user.uid,
          displayName: user.displayName ?? '',
          email: user.email ?? '',
          profileImageUrl: user.photoURL,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await createOrUpdateUserProfile(userModel);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('初期プロフィール作成エラー: $e');
      }
      throw Exception('初期プロフィールの作成に失敗しました: $e');
    }
  }

  // ユーザープロフィールの作成・更新
  Future<void> createOrUpdateUserProfile(UserModel userModel) async {
    try {
      await _firestore
          .collection('users')
          .doc(userModel.uid)
          .set(userModel.toFirestore(), SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('プロフィール保存エラー: $e');
      }
      throw Exception('ユーザープロフィールの保存に失敗しました: $e');
    }
  }

  // 現在のユーザープロフィールの取得
  Future<UserModel?> getCurrentUserProfile() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        if (kDebugMode) {
          debugPrint('❌ ユーザーがログインしていません');
        }
        return null;
      }

      final userId = currentUser.uid;
      if (userId.isEmpty) {
        if (kDebugMode) {
          debugPrint('❌ ユーザーIDが空です');
        }
        return null;
      }

      if (kDebugMode) {
        debugPrint('🔍 プロフィール取得開始 - User ID: $userId');
      }

      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .get();

      if (!doc.exists) {
        if (kDebugMode) {
          debugPrint('⚠️ ユーザープロフィールが存在しません - 初期プロフィールを作成します');
        }

        // 初期プロフィールを作成
        await createInitialProfile(currentUser);

        // 再度取得
        final newDoc = await _firestore
            .collection('users')
            .doc(userId)
            .get();

        if (newDoc.exists) {
          return UserModel.fromFirestore(newDoc.data()!);
        }
        return null;
      }

      final userData = doc.data()!;
      if (kDebugMode) {
        debugPrint('✅ プロフィール取得成功');
      }

      return UserModel.fromFirestore(userData);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ プロフィール取得エラー: $e');
      }
      return null;
    }
  }

  // 特定のユーザープロフィールの取得
  Future<UserModel?> getUserProfile(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();

      if (doc.exists && doc.data() != null) {
        return UserModel.fromFirestore(doc.data()!);
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ユーザープロフィール取得エラー: $e');
      }
      return null;
    }
  }

  // プロフィールの更新
  Future<void> updateUserProfile({
    String? displayName,
    String? bio,
    String? profileImageUrl,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('ユーザーがログインしていません');
      }

      // ✅ ユーザーIDの有効性をチェック
      final userId = currentUser.uid;
      if (userId.isEmpty) {
        throw Exception('ユーザーIDが取得できません');
      }

      if (kDebugMode) {
        debugPrint('🔄 プロフィール更新開始 - User ID: $userId');
        debugPrint('  - Display Name: $displayName');
        debugPrint('  - Bio: $bio');
        debugPrint('  - Profile Image: $profileImageUrl');
      }

      // 更新データを準備
      final updateData = <String, dynamic>{};

      if (displayName != null) {
        updateData['displayName'] = displayName;
      }
      if (bio != null) {
        updateData['bio'] = bio;
      }
      if (profileImageUrl != null) {
        updateData['profileImageUrl'] = profileImageUrl;
      }

      // 更新日時を追加
      updateData['updatedAt'] = Timestamp.now();

      if (updateData.isEmpty) {
        if (kDebugMode) {
          debugPrint('⚠️ 更新するデータがありません');
        }
        return;
      }

      // ✅ ドキュメントパスを明示的に指定
      await _firestore
          .collection('users')
          .doc(userId) // 明示的にuserIdを指定
          .update(updateData);

      if (kDebugMode) {
        debugPrint('✅ プロフィール更新成功');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ プロフィール更新エラー: $e');
      }
      throw Exception('プロフィールの更新に失敗しました: $e');
    }
  }

  // プロフィール画像の更新
  Future<void> updateProfileImage(String imageUrl) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('ユーザーがログインしていません');

      await _firestore.collection('users').doc(user.uid).update({
        'profileImageUrl': imageUrl,
        'updatedAt': Timestamp.now(), // Timestamp形式で更新
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('プロフィール画像更新エラー: $e');
      }
      throw Exception('プロフィール画像の更新に失敗しました: $e');
    }
  }

  // アクティブユーザー数を取得
  Future<int> getActiveUsersCount() async {
    try {
      final now = DateTime.now();
      final lastWeek = now.subtract(const Duration(days: 7));
      final lastWeekTimestamp = Timestamp.fromDate(lastWeek);

      final querySnapshot = await _firestore
          .collection('users')
          .where('updatedAt', isGreaterThan: lastWeekTimestamp)
          .get();

      return querySnapshot.docs.length;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('アクティブユーザー数取得エラー: $e');
      }
      return 0;
    }
  }

  // 今日のマッチング可能ユーザー数を取得
  Future<int> getAvailableUsersCount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 0;

      // 全ユーザー数を取得
      final allUsersQuery = await _firestore.collection('users').get();
      final totalUsers = allUsersQuery.docs.length;

      // 過去にマッチしたユーザーを取得
      final matchesQuery = await _firestore
          .collection('matches')
          .where('participants', arrayContains: user.uid)
          .get();

      final previousMatches = <String>{};
      for (var doc in matchesQuery.docs) {
        final participants = List<String>.from(doc.data()['participants'] ?? []);
        for (var participant in participants) {
          if (participant != user.uid) {
            previousMatches.add(participant);
          }
        }
      }

      // マッチング可能数 = 全ユーザー - 自分 - 過去のマッチング相手
      final availableCount = totalUsers - 1 - previousMatches.length;

      if (kDebugMode) {
        debugPrint('📊 マッチング可能ユーザー計算:');
        debugPrint('  - 全ユーザー: $totalUsers');
        debugPrint('  - 過去のマッチング: ${previousMatches.length}');
        debugPrint('  - マッチング可能: $availableCount');
      }

      return availableCount > 0 ? availableCount : 0;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('利用可能ユーザー数取得エラー: $e');
      }
      return 0;
    }
  }

  /// 他のユーザーから現在のユーザーへのフィードバックリストを取得する
  Future<List<FeedbackData>> getFeedbacksForCurrentUser() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return [];
    }
    final uid = currentUser.uid;

    try {
      if (kDebugMode) {
        debugPrint('🔍 フィードバック検索開始 - ユーザーID: $uid');
      }

      // ✅ Firebaseの実際の構造に合わせて修正
      final querySnapshot = await _firestore
          .collection('mission_results') // ✅ 正しいコレクション名
          .where('userId', isEqualTo: uid) // ✅ 'userId' フィールドを使用
          .orderBy('submittedAt', descending: true) // ✅ 'submittedAt' フィールドを使用
          .get();

      if (kDebugMode) {
        debugPrint('📊 mission_results検索結果: ${querySnapshot.docs.length}件');

        // データ構造をログ出力
        for (final doc in querySnapshot.docs) {
          debugPrint('📄 ドキュメント ${doc.id}:');
          debugPrint('   データ: ${doc.data()}');
        }
      }

      if (querySnapshot.docs.isEmpty) {
        if (kDebugMode) {
          debugPrint('⚠️ フィードバックデータが見つかりません');
        }
        return [];
      }

      // ✅ 実際のFirebase構造に合わせてデータ変換
      final feedbacks = querySnapshot.docs
          .map((doc) {
            final data = doc.data();

            return FeedbackData(
              id: doc.id,
              fromUserId: data['submitterId'] ?? '',
              targetUserId: data['userId'] ?? '',
              feedbackText: data['feedbackText'] ?? '',
              missionQuestion: data['missionQuestion'] ?? 'ミッション内容不明',
              fromUserName: data['submitterName'] ?? '匿名',
              createdAt: (data['submittedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
              matchId: data['matchId'] ?? '',                      // ← 追加
              organizationId: data['organizationId'] ?? 'default', // ← 追加
            );
          })
          .toList();

      if (kDebugMode) {
        debugPrint('✅ フィードバック変換成功: ${feedbacks.length}件');
      }

      return feedbacks;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ フィードバック取得エラー: $e');
      }
      return [];
    }
  }

  /// AIプロフィールデータを取得（特定のユーザーID用）
  Future<AIProfileData?> getAIProfile(String userId) async {
    try {
      final doc = await _firestore.collection('aiProfiles').doc(userId).get();
      if (doc.exists && doc.data() != null) {
        return AIProfileData.fromFirestore(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ AIプロフィール取得エラー: $e');
      }
      return null;
    }
  }

  /// 現在のユーザーのAIプロフィールを取得
  Future<AIProfileData?> getCurrentUserAIProfile() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      if (kDebugMode) {
        debugPrint('❌ 現在のユーザーが見つかりません');
      }
      return null;
    }
    // 上の getAIProfile メソッドを呼び出す
    return await getAIProfile(currentUser.uid);
  }

/// AIプロフィール生成をCloud Functionsで実行
Future<Map<String, dynamic>> generateAIProfile() async {
  try {
    final HttpsCallable callable = _functions.httpsCallable('generateAiProfile');
    final result = await callable.call();

    if (kDebugMode) {
      debugPrint('✅ AIプロフィール生成成功: ${result.data}');
    }

    // ⭐ 追加：成功時に自動的にAIプロフィールを再読み込み
    if (result.data['success'] == true) {
      // 少し待ってからFirestoreの更新を反映
      await Future.delayed(const Duration(milliseconds: 500));

      if (kDebugMode) {
        debugPrint('🔄 AIプロフィール再読み込み完了');
      }
    }

    return result.data;
  } catch (e) {
    if (kDebugMode) {
      debugPrint('❌ AIプロフィール生成エラー: $e');
    }
    rethrow;
  }
}

/// テスト用hello関数の呼び出し
  Future<Map<String, dynamic>> testHelloFunction() async {
    try {
      final HttpsCallable callable = _functions.httpsCallable('hello');
      final result = await callable.call();

      if (kDebugMode) {
        debugPrint('✅ Hello関数テスト成功: ${result.data}');
      }

      return result.data;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Hello関数テストエラー: $e');
      }
      rethrow;
    }
  }

/// AIプロフィールを再生成する
  Future<Map<String, dynamic>> regenerateAIProfile() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('ユーザーがログインしていません');
      }

      if (kDebugMode) {
        debugPrint('🔄 AIプロフィール再生成開始');
      }

      // ✅ 強制再生成フラグ付きで呼び出し
      final HttpsCallable callable = _functions.httpsCallable('generateAiProfile');
      final result = await callable.call({
        'forceRegenerate': true,  // 既存データがあっても再生成
      });

      if (kDebugMode) {
        debugPrint('✅ AIプロフィール再生成完了: ${result.data}');
      }

      return Map<String, dynamic>.from(result.data);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ AIプロフィール再生成エラー: $e');
      }
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
}
