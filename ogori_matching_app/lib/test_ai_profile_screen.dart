import 'package:flutter/material.dart';
import 'services/user_service.dart';
import 'models/ai_profile_model.dart';

class TestAiProfileScreen extends StatefulWidget {
  const TestAiProfileScreen({super.key});

  @override
  State<TestAiProfileScreen> createState() => _TestAiProfileScreenState();
}

class _TestAiProfileScreenState extends State<TestAiProfileScreen> {
  final UserService _userService = UserService();
  String _result = '';
  bool _isLoading = false;
  AIProfileData? _currentProfile;

  @override
  void initState() {
    super.initState();
    _loadCurrentProfile();
  }

  Future<void> _loadCurrentProfile() async {
    try {
      final profile = await _userService.getCurrentUserAIProfile();
      setState(() {
        _currentProfile = profile;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _result = 'プロフィール読み込みエラー: $e';
        });
      }
    }
  }

  Future<void> _testProfileGeneration() async {
    setState(() {
      _isLoading = true;
      _result = '';
    });

    try {
      // プロフィール生成をテスト
      final result = await _userService.generateAIProfile();

      // 結果を更新
      await _loadCurrentProfile();

      setState(() {
        if (result['success'] == true) {
          _result = '''✅ 成功！AIプロフィール生成完了

📊 メタデータ:
- モデル: ${result['metadata']?['modelUsed'] ?? '不明'}
- 生成時刻: ${result['profile']?['generatedAt'] ?? '不明'}
- フィードバック数: ${result['profile']?['feedbackCount'] ?? 0}件
- 構造化出力: ${result['metadata']?['hasStructuredOutput'] ?? false}

🎯 生成されたプロフィール:
${_formatProfile(_currentProfile)}''';
        } else {
          _result = '''⚠️ フォールバック発動
理由: ${result['metadata']?['reason'] ?? '不明'}
エラー: ${result['metadata']?['error'] ?? '詳細なし'}''';
        }
      });
    } catch (e) {
      setState(() {
        _result = '❌ エラー: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _formatProfile(AIProfileData? profile) {
    if (profile == null) return '読み込み中...';

    return '''
【総合的な人物像】
${profile.comprehensivePersonality}

【ヨコク】
${profile.futurePreview}

【キーワード】
${profile.keywordsList.map((k) => '#$k').join(' ')}
''';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AIプロフィール生成テスト'),
        backgroundColor: Colors.purple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 現在のプロフィール表示
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '📋 現在のAIプロフィール',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Text(_formatProfile(_currentProfile)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // テストボタン
            ElevatedButton(
              onPressed: _isLoading ? null : _testProfileGeneration,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(width: 12),
                      Text('生成中...'),
                    ],
                  )
                : const Text('🤖 AIプロフィール生成テスト'),
            ),

            const SizedBox(height: 20),

            // 結果表示
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '📊 テスト結果',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Text(
                            _result.isEmpty ? 'テストボタンを押して開始してください' : _result,
                            style: const TextStyle(fontFamily: 'monospace'),
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
