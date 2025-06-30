import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../services/matching_service.dart';
import '../models/user_model.dart';
import 'match_success_screen.dart';

class MatchingScreen extends StatefulWidget {
  final String queueId;

  const MatchingScreen({
    super.key,
    required this.queueId,
  });

  @override
  State<MatchingScreen> createState() => _MatchingScreenState();
}

class _MatchingScreenState extends State<MatchingScreen>
    with TickerProviderStateMixin {
  final MatchingService _matchingService = MatchingService();

  late AnimationController _searchController;
  late AnimationController _successController;

  bool _isSearching = true;
  bool _matchFound = false;
  UserModel? _matchedUser;
  String _searchText = 'マッチング待機列に参加中...';
  String? _queueId;
  String? _matchId; // ✨ 追加: マッチIDを保存
  int _waitingCount = 0;

  // ✨ リアルタイム監視用
  StreamSubscription<DocumentSnapshot>? _queueSubscription;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startMatching();
  }

  void _setupAnimations() {
    _searchController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _successController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _searchController.repeat();
  }

  Future<void> _startMatching() async {
    try {
      setState(() {
        _searchText = 'マッチング処理を開始しています...';
      });

      // ✨ Firebase Functionsでマッチング処理を実行
      final result = await _matchingService.processMatching();

      if (result.isMatched && result.partner != null) {
        // 即座にマッチング成立
        if (kDebugMode) {
          debugPrint('🎉 即座にマッチング成立！');
        }
        _matchId = result.matchId; // ✨ マッチIDを保存
        await _showMatchSuccess(result.partner!);
      } else if (result.isWaiting && result.queueId != null) {
        // 待機キューに追加された
        _queueId = result.queueId;

        setState(() {
          _waitingCount = result.waitingCount;
          _searchText = '他のユーザーを待機中... (待機中: ${result.waitingCount}人)';
        });

        // リアルタイム監視開始
        _startQueueWatching();

        // 定期的な状態更新
        await _waitForMatch();
      }

    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ マッチングエラー: $e');
      }
      await _showMatchFailure('マッチング処理でエラーが発生しました');
    }
  }

  Future<void> _waitForMatch() async {
    int attempts = 0;
    const maxAttempts = 60; // 60秒間待機

    while (attempts < maxAttempts && _isSearching && mounted) {
      try {
        await _updateWaitingCount();

        setState(() {
          _searchText = 'マッチング相手を待機中... (${attempts + 1}/${maxAttempts}s)';
        });

        await Future.delayed(const Duration(seconds: 1));
        attempts++;
      } catch (e) {
        if (kDebugMode) {
          debugPrint('❌ 待機処理エラー: $e');
        }
        break;
      }
    }

    // タイムアウト後もリアルタイム監視は継続
    setState(() {
      _searchText = 'マッチング待機中...\n他のユーザーの参加をお待ちください';
    });
  }

  // ✨ リアルタイム監視開始
  void _startQueueWatching() {
    if (_queueId == null) return;

    _queueSubscription = _matchingService
        .watchMyQueueStatus(_queueId!)
        .listen((snapshot) async {
      if (!snapshot.exists || !mounted) return;

      final data = snapshot.data() as Map<String, dynamic>;
      final status = data['status'] as String?;
      final partnerId = data['partnerId'] as String?;

      if (kDebugMode) {
        debugPrint('📡 キューステータス更新: $status');
        if (partnerId != null) {
          debugPrint('🤝 マッチング相手: $partnerId');
        }
      }

      // マッチング成立時の処理
      if (status == 'matched' && partnerId != null && _isSearching) {
        if (kDebugMode) {
          debugPrint('🎉 リアルタイムマッチング検出！');
        }

        // 相手のプロフィールを取得
        final matchedUser = await _matchingService.getMatchedPartner(partnerId);
        if (matchedUser != null) {
          // マッチIDも生成（リアルタイム検出の場合）
          _matchId = 'match-${DateTime.now().millisecondsSinceEpoch}';
          await _showMatchSuccess(matchedUser);
        }
      }
    });
  }

  Future<void> _updateWaitingCount() async {
    try {
      final count = await _matchingService.getWaitingUsersCount();
      setState(() {
        _waitingCount = count;
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('待機数更新エラー: $e');
      }
    }
  }

  Future<void> _showMatchSuccess(UserModel matchedUser) async {
    if (!_isSearching) return; // 重複実行防止

    setState(() {
      _isSearching = false;
      _matchFound = true;
      _matchedUser = matchedUser;
      _searchText = 'マッチング成功！';
    });

    _searchController.stop();
    _successController.forward();

    // リアルタイム監視停止
    _queueSubscription?.cancel();

    // マッチング記録
    await _matchingService.recordMatch(matchedUser.uid);

    if (kDebugMode) {
      debugPrint('🎊 マッチング成功処理完了！');
    }

    // 3秒後に結果画面に移動
    await Future.delayed(const Duration(seconds: 3));
    if (mounted) {
      _showMatchResult();
    }
  }

  Future<void> _showMatchFailure(String message) async {
    setState(() {
      _isSearching = false;
      _matchFound = false;
      _searchText = message;
    });

    _searchController.stop();

    // ✨ 修正: 非推奨メソッドを新しいメソッドに置き換え
    if (_queueId != null) {
      try {
        await _matchingService.cancelMatching(queueId: _queueId);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('❌ キャンセル処理エラー: $e');
        }
      }
    }

    await Future.delayed(const Duration(seconds: 3));
    if (mounted) {
      Navigator.pop(context);
    }
  }

  void _showMatchResult() {
    if (_matchedUser == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ビジネス向けアイコン
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue.shade50,
                border: Border.all(
                  color: Colors.blue.shade300,
                  width: 3,
                ),
              ),
              child: const Icon(
                Icons.handshake_outlined,
                color: Colors.blue,
                size: 40,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'マッチング成功！',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'コラボレーションパートナーが見つかりました',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // パートナー情報（簡略版）
            Text(
              _matchedUser!.displayName.isNotEmpty
                  ? _matchedUser!.displayName
                  : '匿名ユーザー',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            if (_matchedUser!.location?.isNotEmpty == true) ...[
              const SizedBox(height: 4),
              Text(
                _matchedUser!.location!,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ],
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () {
                    // 開発中メッセージを表示
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('この機能は現在開発中です'),
                        duration: Duration(seconds: 2),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.grey.shade100,
                    foregroundColor: Colors.grey.shade700,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    '後で確認',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // ダイアログを閉じる
                    // MatchSuccessScreenに遷移
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MatchSuccessScreen(
                          matchedUser: _matchedUser!,
                          matchId: _matchId ?? 'match-${DateTime.now().millisecondsSinceEpoch}', // ✨ 修正
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'ミッション開始',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _closeScreen() async {
    // リアルタイム監視停止
    _queueSubscription?.cancel();

    // ✨ Firebase Functionsでキャンセル処理
    if (_queueId != null) {
      try {
        await _matchingService.cancelMatching(queueId: _queueId);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('❌ キャンセル処理エラー: $e');
        }
      }
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    // リアルタイム監視停止
    _queueSubscription?.cancel();

    _searchController.dispose();
    _successController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // ヘッダー
              Row(
                children: [
                  IconButton(
                    onPressed: _closeScreen,
                    icon: const Icon(Icons.close),
                  ),
                  const Expanded(
                    child: Text(
                      'OGORI MATCH',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),

              const Spacer(),

              // メインコンテンツ
              if (_isSearching) ...[
                AnimatedBuilder(
                  animation: _searchController,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: 1.0 + (_searchController.value * 0.1),
                      child: Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.blue.withValues(alpha: 0.1),
                          border: Border.all(
                            color: Colors.blue.withValues(alpha: 0.3),
                            width: 2,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.people,
                              size: 40,
                              color: Colors.blue,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '$_waitingCount',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                            const Text(
                              '待機中',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 40),
                Text(
                  _searchText,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.blue,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                const CircularProgressIndicator(),
              ] else if (_matchFound && _matchedUser != null) ...[
                // ✨ ビジネス向けマッチング成功表示
                AnimatedBuilder(
                  animation: _successController,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _successController.value,
                      child: Column(
                        children: [
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.green.withValues(alpha: 0.1),
                              border: Border.all(
                                color: Colors.green,
                                width: 3,
                              ),
                            ),
                            child: const Icon(
                              Icons.check,
                              size: 60,
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'マッチング成功！',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (_matchedUser != null) ...[
                            Text(
                              '${_matchedUser!.displayName}さんとマッチしました',
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton(
                              onPressed: _showMatchResult,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 32,
                                  vertical: 12,
                                ),
                              ),
                              child: const Text('詳細を見る'),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ] else ...[
                // マッチング失敗表示
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.orange.withValues(alpha: 0.1),
                    border: Border.all(
                      color: Colors.orange,
                      width: 3,
                    ),
                  ),
                  child: const Icon(
                    Icons.timer,
                    size: 60,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'マッチング待機中',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  '他のユーザーの参加をお待ちください',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                ),
              ],

              const Spacer(),

              // 説明
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Column(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.blue,
                      size: 24,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'マッチングが成立すると、AIが生成したミッションが開始されます',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
