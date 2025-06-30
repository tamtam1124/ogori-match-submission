// lib/test_mission_screen.dart を修正

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/mission_service.dart';
import 'package:flutter/foundation.dart'; // debugPrint用

class TestMissionScreen extends StatefulWidget {
  const TestMissionScreen({super.key});

  @override
  State<TestMissionScreen> createState() => _TestMissionScreenState();
}

class _TestMissionScreenState extends State<TestMissionScreen> {
  final MissionService _missionService = MissionService();
  String _result = '';
  bool _isLoading = false;

  /// ✅ 修正：認証ベースのミッション生成テスト
  Future<void> _testMissionGeneration() async {
    setState(() {
      _isLoading = true;
      _result = '';
    });

    try {
      // ✅ 認証確認
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        setState(() {
          _result = 'エラー: ユーザーがログインしていません';
        });
        return;
      }

      if (kDebugMode) {
        debugPrint('🎯 ミッション生成開始');
        debugPrint('   - 現在のユーザー: ${currentUser.uid}');
      }

      final result = await _missionService.generateMission();

      setState(() {
        _result = '''✅ 成功！
ミッション: ${result.missionText}
フォールバック: ${result.isFallback}
ミッションID: ${result.missionId ?? '未設定'}
参加者数: ${result.participantCount}
${result.participantsText}
生成日時: ${result.generatedAt?.toString() ?? '未設定'}''';
      });

      if (kDebugMode) {
        debugPrint('✅ ミッション取得成功');
        debugPrint('   - ミッション: ${result.missionText}');
        debugPrint('   - フォールバック: ${result.isFallback}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ ミッション生成エラー: $e');
      }
      setState(() {
        _result = 'エラー: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// ✅ 新機能：パートナー指定でのテスト
  Future<void> _testMissionGenerationWithPartner() async {
    setState(() {
      _isLoading = true;
      _result = '';
    });

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        setState(() {
          _result = 'エラー: ユーザーがログインしていません';
        });
        return;
      }

      // パートナーIDを指定（実際のユーザーIDまたはテスト用ID）
      final result = await _missionService.generateMission(
        partnerUserId: 'test-partner-id',  // 必要に応じて変更
      );

      setState(() {
        _result = '''✅ パートナー指定で成功！
ミッション: ${result.missionText}
フォールバック: ${result.isFallback}
${result.participantsText}''';
      });
    } catch (e) {
      setState(() {
        _result = 'パートナー指定エラー: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ミッション生成テスト'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ✅ 現在のユーザー情報表示
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '現在のユーザー',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    StreamBuilder<User?>(
                      stream: FirebaseAuth.instance.authStateChanges(),
                      builder: (context, snapshot) {
                        if (snapshot.hasData) {
                          final user = snapshot.data!;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('UID: ${user.uid}'),
                              Text('Email: ${user.email ?? '未設定'}'),
                              Text('名前: ${user.displayName ?? '未設定'}'),
                            ],
                          );
                        }
                        return const Text('❌ ログインしていません');
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ✅ テストボタンを2つに分離
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _testMissionGeneration,
              icon: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome),
              label: Text(_isLoading ? '生成中...' : '🤖 ミッション生成テスト（自動パートナー選択）'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),

            const SizedBox(height: 12),

            ElevatedButton.icon(
              onPressed: _isLoading ? null : _testMissionGenerationWithPartner,
              icon: const Icon(Icons.person_add),
              label: const Text('👥 パートナー指定テスト'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),

            const SizedBox(height: 20),

            // ✅ 結果表示エリアの改善
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '実行結果',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _result.isEmpty ? '結果がここに表示されます' : _result,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
