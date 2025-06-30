import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../services/mission_state_service.dart';
import '../services/mission_service.dart';
import 'mission_display_screen.dart';

class MatchSuccessScreen extends StatefulWidget {
  final UserModel matchedUser;
  final String matchId;

  const MatchSuccessScreen({
    Key? key,
    required this.matchedUser,
    required this.matchId,
  }) : super(key: key);

  @override
  State<MatchSuccessScreen> createState() => _MatchSuccessScreenState();
}

class _MatchSuccessScreenState extends State<MatchSuccessScreen>
    with TickerProviderStateMixin {

  final MissionStateService _missionStateService = MissionStateService();
  final MissionService _missionService = MissionService();

  late AnimationController _celebrationController;
  late Animation<double> _scaleAnimation;

  bool _isGeneratingMission = false;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startCelebration();
  }

  void _setupAnimations() {
    _celebrationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _celebrationController,
      curve: Curves.elasticOut,
    ));
  }

  void _startCelebration() {
    _celebrationController.forward();
  }

  @override
  void dispose() {
    _celebrationController.dispose();
    super.dispose();
  }

  Future<void> _startMission() async {
    setState(() {
      _isGeneratingMission = true;
    });

    try {
      if (kDebugMode) {
        debugPrint('🎯 ミッション生成開始');
        debugPrint('   - マッチID: ${widget.matchId}');
        debugPrint('   - パートナー: ${widget.matchedUser.displayName}');
      }

      final mission = await _missionService.generateMission(
        partnerUserId: widget.matchedUser.uid,
      );

      // ミッション状態を保存
      await _missionStateService.assignMission(
        missionId: mission.missionId ?? 'generated-${DateTime.now().millisecondsSinceEpoch}',
        missionText: mission.missionText,
        matchId: widget.matchId,
        partnerUserId: widget.matchedUser.uid,
        partnerDisplayName: widget.matchedUser.displayName,
      );

      if (kDebugMode) {
        debugPrint('✅ ミッション生成・保存完了');
      }

      // ミッション表示画面に遷移
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => MissionDisplayScreen(
              matchId: widget.matchId,
              matchedUser: widget.matchedUser,
            ),
          ),
        );
      }

    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ ミッション生成エラー: $e');
      }

      if (mounted) {
        _showErrorDialog('ミッションの生成に失敗しました。\n$e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingMission = false;
        });
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('エラー'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // MatchSuccessScreenも閉じる
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _goHome() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom - 32,
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                // ヘッダー
                Row(
                  children: [
                    IconButton(
                      onPressed: _goHome,
                      icon: const Icon(Icons.close),
                    ),
                    const Expanded(
                      child: Text(
                        'マッチング成功',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48), // IconButtonの幅分のスペース
                  ],
                ),

                const SizedBox(height: 24),

                // 成功アニメーション
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: Column(
                    children: [
                      // 成功アイコン
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.handshake_outlined,
                          size: 60,
                          color: Colors.green.shade600,
                        ),
                      ),

                      const SizedBox(height: 32),

                      // 成功メッセージ
                      const Text(
                        'マッチング成功！',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),

                      const SizedBox(height: 16),

                      const Text(
                        '今すぐ、おごり自販機に集合し、マッチング相手を探しましょう',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // パートナー情報
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        // パートナーのアバター
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.blue.shade200,
                          backgroundImage: (widget.matchedUser.profileImageUrl != null &&
                                            widget.matchedUser.profileImageUrl!.isNotEmpty)
                              ? NetworkImage(widget.matchedUser.profileImageUrl!)
                              : null,
                          child: (widget.matchedUser.profileImageUrl == null ||
                                  widget.matchedUser.profileImageUrl!.isEmpty)
                              ? Icon(
                                  Icons.person,
                                  size: 40,
                                  color: Colors.blue.shade600,
                                )
                              : null,
                        ),

                        const SizedBox(height: 16),

                        // パートナー名
                        Text(
                          widget.matchedUser.displayName.isNotEmpty
                              ? widget.matchedUser.displayName
                              : '匿名ユーザー',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),

                        if (widget.matchedUser.location?.isNotEmpty == true) ...[
                          const SizedBox(height: 8),
                          Text(
                            widget.matchedUser.location!,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // アクションボタン
                _buildActionButtons(),

                const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        // メインボタン：ミッション開始
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _isGeneratingMission ? null : _startMission,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade500,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
            ),
            child: _isGeneratingMission
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'ミッション生成中...',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.assignment_outlined, size: 24),
                      SizedBox(width: 12),
                      Text(
                        'コラボレーションミッション開始',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}
