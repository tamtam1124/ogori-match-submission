import 'package:flutter/material.dart';
//import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/ai_profile_model.dart';
import '../models/user_model.dart';
import '../services/user_service.dart';

class OtherPerspectiveProfileScreen extends StatefulWidget {
  const OtherPerspectiveProfileScreen({super.key});

  @override
  State<OtherPerspectiveProfileScreen> createState() =>
      _OtherPerspectiveProfileScreenState();
}

class _OtherPerspectiveProfileScreenState
    extends State<OtherPerspectiveProfileScreen> {
  // --- 1. この画面が使う道具や状態を定義 ---
  final UserService _userService = UserService();
  UserModel? _currentUser; // ヘッダーに表示するユーザー情報
  bool _isLoadingProfile = true; // ヘッダー情報を読み込み中かどうかのフラグ

  // AIプロフィールの取得処理（未来の結果）を保持する変数
  late Future<AIProfileData?> _aiProfileFuture;

  // 再生成用の状態変数
  bool _isRegenerating = false;

  // --- 2. 画面が最初に表示されたときの処理 ---
  @override
  void initState() {
    super.initState();
    // ユーザーの基本情報と、AIプロフィールの両方の読み込みを開始
    _loadInitialData();
  }

  void _loadInitialData() {
    _loadUserProfile(); // ヘッダー用のユーザー情報を読み込む
    _aiProfileFuture = _userService.getCurrentUserAIProfile(); // メインコンテンツ用のAIプロフィールを読み込む
  }

  // ヘッダーに表示するユーザー情報を取得する
  Future<void> _loadUserProfile() async {
    // setStateを使って、画面の一部を更新するように伝える
    setState(() {
      _isLoadingProfile = true;
    });
    final user = await _userService.getCurrentUserProfile();
    if (mounted) {
      setState(() {
        _currentUser = user;
        _isLoadingProfile = false;
      });
    }
  }

  // AIプロフィールを再読み込みしたいときに呼び出す
  void _refreshAIProfile() {
    setState(() {
      _aiProfileFuture = _userService.getCurrentUserAIProfile();
    });
  }

  // --- 3. 画面の見た目を構築するメインの部分 ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AIが分析したあなた'),
      ),
      // まずはヘッダー用のプロフィールが読み込み中かチェック
      body: _isLoadingProfile
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 3-1. 画面上部のプロフィールヘッダー
                _buildProfileHeader(),

                // 3-2. 残りの領域全てを使って、AIプロフィールの状態を表示
                Expanded(
                  child: FutureBuilder<AIProfileData?>(
                    future: _aiProfileFuture, // この処理が終わるのを待つ
                    builder: (context, snapshot) {
                      // 【分岐A】読み込み中の場合
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      // 【分岐B】エラーが発生した場合
                      if (snapshot.hasError) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
                              const SizedBox(height: 16),
                              Text('データ取得エラー: ${snapshot.error}'),
                              ElevatedButton(
                                onPressed: () => _refreshAIProfile(),
                                child: const Text('再試行'),
                              ),
                            ],
                          ),
                        );
                      }

                      // 【分岐C】データが取得できた場合
                      final aiProfile = snapshot.data;
                      if (aiProfile != null) {
                        // データがあったので、内容を表示する部品を呼び出す
                        return _buildAIProfileContent(aiProfile);
                      } else {
                        // データがなかったので、「未作成」の表示部品を呼び出す
                        return _buildNoDataSection();
                      }
                    },
                  ),
                ),
              ],
            ),
    );
  }

  // --- 4. 画面の各部分を作るための部品（メソッド）たち ---

  /// 画面上部のプロフィールヘッダーを作る部品
  Widget _buildProfileHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      color: Colors.grey[100],
      child: Column(
        children: [
          Text(
            _currentUser?.displayName ?? '名前未設定',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            _currentUser?.location ?? '所属未設定',
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  /// データがある場合に、AIプロフィール全体を表示する部品
  Widget _buildAIProfileContent(AIProfileData aiProfile) {
    // SingleChildScrollViewで、内容が長くてもスクロールできるようにする
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. 総合的な人物像
          _buildSectionCard(
            title: '🧠 AIが考えたあなたの人物像',
            content: aiProfile.comprehensivePersonality,
            color: Colors.blue.shade50,
            borderColor: Colors.blue.shade200,
          ),
          const SizedBox(height: 20),

          // 2. ヨコク（予告）
          _buildSectionCard(
            title: '🔮 AIが考えたあなたのヨコク',
            content: aiProfile.futurePreview,
            color: Colors.purple.shade50,
            borderColor: Colors.purple.shade200,
          ),
          const SizedBox(height: 20),

          // 3. キーワード5つ
          _buildKeywordsSection(aiProfile.keywordsList),

          // 再生成セクション
        const SizedBox(height: 32),
        _buildRegenerationSection(),
        ],
      ),
    );
  }

  /// データがない場合に、「未作成」のメッセージとボタンを表示する部品
  Widget _buildNoDataSection() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.psychology_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'AIプロフィールはまだ作成されていません',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'あなたのフィードバックデータを基に、AIがあなたの特徴や魅力を分析します。',
              style: TextStyle(fontSize: 14, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            ElevatedButton.icon(
              icon: const Icon(Icons.auto_awesome),
              label: const Text('AIプロフィールを生成する'),
              onPressed: () async {
                try {
                  // ローディング表示
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => const Center(
                      child: CircularProgressIndicator(),
                    ),
                  );

                  // ✅ 実際のAIプロフィール生成を実行
                  final result = await _userService.generateAIProfile();

                  // ローディングを閉じる
                  if (mounted) Navigator.pop(context);

                  // ✅ 成功時の処理を改善
                  if (result['success'] == true) {
                    // データ再読み込み
                    _refreshAIProfile();

                    // 成功メッセージ
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('✅ AIプロフィールが生成されました！'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } else {
                    // 失敗時の処理
                    if (mounted) {                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('❌ AIプロフィール生成に失敗しました'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                } catch (e) {
                  // ローディングを閉じる
                  if (mounted) Navigator.pop(context);

                  // エラーメッセージ
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('❌ エラーが発生しました: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 再生成セクションを構築
  Widget _buildRegenerationSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(
            Icons.refresh_rounded,
            color: Colors.blue.shade600,
            size: 32,
          ),
          const SizedBox(height: 12),
          Text(
            'プロフィールを更新',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '新しいフィードバックを反映して\nプロフィールを再生成できます',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isRegenerating ? null : _regenerateAIProfile,
              icon: _isRegenerating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome),
              label: Text(_isRegenerating ? '生成中...' : 'プロフィールを再生成'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- 5. UI表示用のヘルパー部品たち ---

  Widget _buildSectionCard({
    required String title,
    required String content,
    required Color color,
    required Color borderColor,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor, width: 1),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 12),
            Text(content, style: const TextStyle(fontSize: 16, height: 1.6, color: Colors.black87)),
          ],
        ),
      ),
    );
  }

  Widget _buildKeywordsSection(List<String> keywords) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.green.shade200, width: 1),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('🏷️ あなたを象徴するキーワード', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: keywords.map((keyword) => _buildKeywordChip(keyword)).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeywordChip(String keyword) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.green.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green.shade300),
      ),
      child: Text(
        keyword,
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.green.shade800),
      ),
    );
  }

  /// AIプロフィールを再生成する
  Future<void> _regenerateAIProfile() async {
    if (_isRegenerating) return;

    setState(() {
      _isRegenerating = true;
    });

    try {
      // ✅ 強制再生成フラグ付きで呼び出し
      final result = await _userService.regenerateAIProfile();

      if (result['success'] == true) {
        // 成功時の処理
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ プロフィールを更新しました'),
              backgroundColor: Colors.green,
            ),
          );
        }

        // プロフィールデータを再読み込み
        _refreshAIProfile();
      } else {
        throw Exception(result['error'] ?? 'プロフィール生成に失敗しました');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ プロフィール更新に失敗しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRegenerating = false;
        });
      }
    }
  }
}
