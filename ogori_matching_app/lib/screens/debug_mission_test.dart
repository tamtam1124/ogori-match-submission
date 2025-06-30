import 'package:flutter/material.dart';
import 'mission_display_screen.dart';
import '../models/user_model.dart';

class DebugMissionTest extends StatelessWidget {
  const DebugMissionTest({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🚀 ミッション機能テスト'),
        backgroundColor: Colors.orange[300],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.assignment_outlined,
              size: 80,
              color: Colors.orange,
            ),
            const SizedBox(height: 24),

            const Text(
              'ミッション機能のテスト',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            const Text(
              '実装したミッション表示→フィードバック画面の\n動作を確認できます',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 48),

            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: () => _openMissionDisplay(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[500],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.play_arrow, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'ミッション表示画面を開く',
                      style: TextStyle(fontSize: 18),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade600, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'テストフロー',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '1. ミッション表示画面が開く\n'
                    '2. パートナー情報とミッションが表示\n'
                    '3. 「ミッション完了」ボタンでフィードバック画面へ\n'
                    '4. フィードバック入力→送信完了',
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openMissionDisplay(BuildContext context) {
    // テスト用ユーザーデータ（emailパラメータを追加）
    final testUser = UserModel(
      uid: 'test-partner-456',
      email: 'partner@example.com',
      displayName: 'コラボパートナー太郎',
      location: '大阪支社・マーケティング部',
      profileImageUrl: null,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MissionDisplayScreen(
          matchId: 'debug-match-${DateTime.now().millisecondsSinceEpoch}',
          matchedUser: testUser,
        ),
      ),
    );
  }
}
