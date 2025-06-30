import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../services/user_service.dart';
import '../models/user_model.dart';
import '../screens/matching_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/other_perspective_profile_screen.dart';
import '../screens/youtube_tutorial_screen.dart';
import '../services/mission_state_service.dart';
import '../models/mission_state.dart';
import 'mission_display_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final UserService _userService = UserService();
  final MissionStateService _missionStateService = MissionStateService();

  UserModel? _currentUser;
  MissionState? _currentMissionState;
  bool _isLoading = true;
  StreamSubscription<MissionState>? _missionStateSubscription;

  @override
  void initState() {
    super.initState();
    _loadData();
    _startMissionStateListener();

    // デバッグ用: 初期ミッション状態確認
    if (kDebugMode) {
      Future.delayed(const Duration(seconds: 2), () async {
        await _missionStateService.debugCurrentState();
      });
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 並列でデータを取得
      final results = await Future.wait([
        _userService.getCurrentUserProfile(),
        _userService.getActiveUsersCount(),
        _userService.getAvailableUsersCount(),
      ]);

      setState(() {
        _currentUser = results[0] as UserModel?;
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('データ読み込みエラー: $e');
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'OGORI MATCH',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        centerTitle: true,
        actions: [
          // チュートリアルボタン
          IconButton(
            icon: const Icon(
              Icons.help_outline,
              size: 28,
            ),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => const YouTubeTutorialScreen(),
              );
            },
            tooltip: "使い方動画",
          ),

          // プロフィールボタン
          IconButton(
            icon: CircleAvatar(
              radius: 16,
              backgroundColor: Colors.blue.shade100,
              backgroundImage: (_currentUser?.profileImageUrl?.isNotEmpty == true)
                  ? NetworkImage(_currentUser!.profileImageUrl!)
                  : null,
              child: (_currentUser?.profileImageUrl?.isNotEmpty != true)
                  ? Icon(Icons.person, size: 20, color: Colors.blue.shade600)
                  : null,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              ).then((_) => _loadData());
            },
          ),

          // ログアウトボタン
          IconButton(
            icon: Icon(
              Icons.logout,
              color: Colors.red.shade600,
              size: 22,
            ),
            onPressed: () => _showLogoutDialog(),
            tooltip: 'ログアウト',
          ),

          const SizedBox(width: 8), // 右端の余白
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ウェルカムメッセージ
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24.0),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.blue.shade600,
                            Colors.blue.shade700,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _buildWelcomeMessage(),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '新しいコラボレーションを始めませんか？',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _startMatching,
                              icon: const Icon(Icons.search, color: Colors.blue),
                              label: const Text(
                                'マッチングを開始',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // 他者視点ボタン
                    _buildOtherPerspectiveButton(),

                    const SizedBox(height: 24),

                    // ミッションセクション
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withValues(alpha: 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.assignment_turned_in,
                                color: Colors.blue.shade600,
                                size: 24,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'ミッションセクション',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // ミッション状態ウィジェット
                          _buildMissionStatusWidget(),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // クイックアクション（本番用のみ）
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withValues(alpha: 0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'クイックアクション',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildQuickActionButton(
                                  'プロフィール編集',
                                  Icons.edit,
                                  Colors.blue,
                                  () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const ProfileScreen(),
                                      ),
                                    ).then((_) => _loadData());
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildQuickActionButton(
                                  'データ更新',
                                  Icons.refresh,
                                  Colors.green,
                                  _loadData,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // データが0の場合の案内メッセージ
                    if (_currentUser == null) ...[
                      const SizedBox(height: 24),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.lightbulb_outline,
                              color: Colors.blue.shade600,
                              size: 48,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'マッチングを始めましょう！',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '「マッチングを開始」ボタンを押して、新しいコラボレーションパートナーを見つけてください。',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.blue.shade700,
                                height: 1.4,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildQuickActionButton(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOtherPerspectiveButton() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const OtherPerspectiveProfileScreen(),
              ),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.purple.shade400,
                  Colors.purple.shade600,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.psychology,
                  size: 48,
                  color: Colors.white,
                ),
                SizedBox(height: 16),
                Text(
                  'AIが分析したあなた',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '他者の視点であなたを知る',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _startMatching() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const MatchingScreen(queueId: ''), // queueIdは画面内で生成
      ),
    ).then((_) => _loadData());
  }

  // ログアウト確認ダイアログを表示
  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.logout,
                color: Colors.red.shade600,
                size: 24,
              ),
              const SizedBox(width: 8),
              const Text(
                'ログアウト',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: const Text(
            'ログアウトしますか？\n再度ログインが必要になります。',
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // ダイアログを閉じる
              },
              child: Text(
                'キャンセル',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // ダイアログを閉じる
                _logout(); // ログアウト実行
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'ログアウト',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ログアウト処理
  Future<void> _logout() async {
    try {
      // ローディング表示
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );
      }

      // Firebase認証からログアウト
      await FirebaseAuth.instance.signOut();

      if (kDebugMode) {
        debugPrint('✅ ログアウト成功');
      }

      // ローディングを閉じる
      if (mounted) {
        Navigator.of(context).pop(); // ローディングを閉じる

        // ✅ AuthWrapperによって自動的にLoginScreenに遷移される
        // 手動での画面遷移は不要
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ ログアウトエラー: $e');
      }

      // エラーの場合はローディングを閉じてエラーメッセージを表示
      if (mounted) {
        Navigator.of(context).pop(); // ローディングを閉じる

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ログアウトに失敗しました: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// ミッション状態のリアルタイム監視を開始
  void _startMissionStateListener() {
    _missionStateSubscription = _missionStateService.watchMissionState().listen(
      (missionState) {
        if (mounted) {
          setState(() {
            _currentMissionState = missionState;
          });
        }
      },
      onError: (error) {
        if (kDebugMode) {
          debugPrint('❌ ミッション状態監視エラー: $error');
        }
      },
    );
  }

  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();
    _missionStateSubscription?.cancel();
  }

  /// ミッション画面を開く
  void _openMissionScreen() {
    final missionState = _currentMissionState;

    // ✅ より安全なnullチェック
    if (missionState == null || !missionState.hasActiveMission) {
      _showMissionErrorDialog('利用可能なミッションがありません');
      return;
    }

    if (kDebugMode) {
      debugPrint('🎯 ミッション画面を開く');
      debugPrint('   - ミッションID: ${missionState.missionId ?? "不明"}');
      debugPrint('   - パートナー: ${missionState.partnerDisplayName ?? "不明"}');
    }

    // 仮のパートナー情報でミッション画面を開く
    final dummyPartner = UserModel(
      uid: missionState.partnerUserId ?? 'unknown',
      email: 'partner@example.com',
      displayName: missionState.partnerDisplayName ?? 'パートナー',
      location: '部署不明',
      profileImageUrl: null,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MissionDisplayScreen(
          matchId: missionState.matchId ?? 'unknown',
          matchedUser: dummyPartner,
        ),
      ),
    );
  }

  void _showMissionErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('お知らせ'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// ミッション状態に応じたウィジェットを作成
  Widget _buildMissionStatusWidget() {
    // ✅ 早期リターンパターンでnullチェック
    final missionState = _currentMissionState;
    if (missionState == null) {
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
              Icons.assignment_outlined,
              color: Colors.grey.shade400,
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              'ミッションがありません',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'マッチングを開始してミッションを受け取りましょう',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // ✅ ここでは missionState は確実に non-null
    switch (missionState.status) {
      case MissionStatus.assigned:
      case MissionStatus.temporarySaved:
        return _buildActiveMissionCard();
      case MissionStatus.completed:
        return _buildCompletedMissionCard();
      case MissionStatus.notAssigned:
        return _buildNoMissionCard();
    }
  }

  Widget _buildActiveMissionCard() {
    // ✅ 安全な参照方法
    final missionState = _currentMissionState;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange.shade400, Colors.orange.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                (missionState?.isTemporarySaved ?? false)
                    ? Icons.bookmark
                    : Icons.assignment_outlined,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                (missionState?.isTemporarySaved ?? false)
                    ? '保存中のミッション'
                    : '進行中のミッション',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Text(
            'パートナー: ${missionState?.partnerDisplayName ?? "不明"}',
            style: TextStyle(
              fontSize: 14,
              color: Colors.orange.shade100,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _openMissionScreen,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.orange.shade600,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'ミッションを続ける',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedMissionCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.check_circle_outline,
                color: Colors.green.shade600,
                size: 24,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '今日のミッションは完了しました',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Text(
            'お疲れさまでした！',
            style: TextStyle(
              fontSize: 14,
              color: Colors.green.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoMissionCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        children: [
          Icon(
            Icons.rocket_launch,
            color: Colors.blue.shade600,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            'ミッションを開始しましょう！',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'マッチングボタンを押して新しいコラボレーションを始めてください',
            style: TextStyle(
              fontSize: 14,
              color: Colors.blue.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ヘルパー関数を追加
  String _buildWelcomeMessage() {
    final user = _currentUser;
    if (user?.displayName.isNotEmpty == true) {
      return 'こんにちは！ ${user!.displayName}さん！';
    }
    return 'こんにちは！';
  }
}
