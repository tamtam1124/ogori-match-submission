import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/mission_state.dart';

class MissionStateService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// 現在のユーザーのミッション状態を取得
  Future<MissionState> getCurrentMissionState() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('ユーザーがログインしていません');
      }

      final doc = await _firestore
          .collection('userMissions')
          .doc(user.uid)
          .get();

      if (!doc.exists) {
        return MissionState.notAssigned();
      }

      final data = doc.data()!;
      return MissionState.fromJson(data);

    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ ミッション状態取得エラー: $e');
      }
      return MissionState.notAssigned();
    }
  }

  /// ミッション状態を保存
  Future<void> saveMissionState(MissionState missionState) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('ユーザーがログインしていません');
      }

      await _firestore
          .collection('userMissions')
          .doc(user.uid)
          .set(missionState.toJson());

      if (kDebugMode) {
        debugPrint('✅ ミッション状態保存成功: ${missionState.status.name}');
      }

    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ ミッション状態保存エラー: $e');
      }
      rethrow;
    }
  }

  /// 新しいミッションを割り当て
  Future<void> assignMission({
    required String missionId,
    required String missionText,
    required String matchId,
    required String partnerUserId,
    required String partnerDisplayName,
  }) async {
    final newState = MissionState.assigned(
      missionId: missionId,
      missionText: missionText,
      matchId: matchId,
      partnerUserId: partnerUserId,
      partnerDisplayName: partnerDisplayName,
      assignedAt: DateTime.now(),
    );

    await saveMissionState(newState);
  }

  /// ミッションを一時保存状態にする
  Future<void> temporarySaveMission() async {
    final currentState = await getCurrentMissionState();

    if (!currentState.isAssigned) {
      throw Exception('保存可能なミッションがありません');
    }

    final savedState = currentState.copyWith(
      status: MissionStatus.temporarySaved,
      temporarySavedAt: DateTime.now(),
    );

    await saveMissionState(savedState);
  }

  /// ミッションを完了状態にする
  Future<void> completeMission(String feedbackText) async {
    final currentState = await getCurrentMissionState();

    if (!currentState.hasActiveMission) {
      throw Exception('完了可能なミッションがありません');
    }

    final completedState = currentState.copyWith(
      status: MissionStatus.completed,
      completedAt: DateTime.now(),
      feedbackText: feedbackText,
    );

    await saveMissionState(completedState);
  }

  /// ミッション状態をリセット（新しい日など）
  Future<void> resetMissionState() async {
    await saveMissionState(MissionState.notAssigned());
  }

  /// ミッション状態の変更を監視
  Stream<MissionState> watchMissionState() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value(MissionState.notAssigned());
    }

    return _firestore
        .collection('userMissions')
        .doc(user.uid)
        .snapshots()
        .map((doc) {
          if (!doc.exists) {
            return MissionState.notAssigned();
          }
          return MissionState.fromJson(doc.data()!);
        });
  }

  /// デバッグ用：現在の状態を確認
  Future<void> debugCurrentState() async {
    if (!kDebugMode) return;

    try {
      final state = await getCurrentMissionState();
      debugPrint('🔍 === 現在のミッション状態 ===');
      debugPrint('   - ステータス: ${state.status.name}');
      debugPrint('   - ミッションID: ${state.missionId}');
      debugPrint('   - ミッション内容: ${state.missionText}');
      debugPrint('   - パートナー: ${state.partnerDisplayName}');
      debugPrint('   - 割り当て日時: ${state.assignedAt}');
      debugPrint('   - 一時保存日時: ${state.temporarySavedAt}');
      debugPrint('   - 完了日時: ${state.completedAt}');
      debugPrint('================================');
    } catch (e) {
      debugPrint('❌ デバッグ状態確認エラー: $e');
    }
  }
}
