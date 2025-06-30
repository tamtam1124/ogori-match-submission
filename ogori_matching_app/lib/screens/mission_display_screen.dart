import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/mission_service.dart';
import '../services/mission_state_service.dart';
import '../models/mission_response.dart';
import '../models/user_model.dart';
import 'mission_feedback_screen.dart';

class MissionDisplayScreen extends StatefulWidget {
  final String matchId;
  final UserModel matchedUser;

  const MissionDisplayScreen({
    super.key,
    required this.matchId,
    required this.matchedUser,
  });

  @override
  State<MissionDisplayScreen> createState() => _MissionDisplayScreenState();
}

class _MissionDisplayScreenState extends State<MissionDisplayScreen>
    with TickerProviderStateMixin {
  final MissionService _missionService = MissionService();
  final MissionStateService _missionStateService = MissionStateService();

  MissionResponse? _currentMission;
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  bool _isSaving = false;

  // アニメーション関連
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadMission();
  }

  void _setupAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutBack,
    ));
  }

  Future<void> _loadMission() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });

      if (kDebugMode) {
        debugPrint('🎯 ミッション生成開始');
        debugPrint('   - マッチID: ${widget.matchId}');
        debugPrint('   - パートナー: ${widget.matchedUser.uid}');
      }

      final mission = await _missionService.generateMission();

      setState(() {
        _currentMission = mission;
        _isLoading = false;
      });

      // アニメーション開始
      _fadeController.forward();
      Future.delayed(const Duration(milliseconds: 200), () {
        _slideController.forward();
      });

      if (kDebugMode) {
        debugPrint('✅ ミッション取得成功');
        debugPrint('   - ミッション: ${mission.missionText}');
        debugPrint('   - フォールバック: ${mission.isFallback}');
      }

    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
        _isLoading = false;
      });

      if (kDebugMode) {
        debugPrint('❌ ミッション取得エラー: $e');
      }
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  void _goToFeedback() {
    if (_currentMission == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MissionFeedbackScreen(
          matchId: widget.matchId,
          missionText: _currentMission!.missionText,
          partnerUserId: widget.matchedUser.uid,
        ),
      ),
    );
  }

  void _regenerateMission() {
    _loadMission();
  }

  /// ミッションを一時保存
  Future<void> _temporarySaveMission() async {
    setState(() {
      _isSaving = true;
    });

    try {
      // まずミッション状態を確認・保存
      await _missionStateService.assignMission(
        missionId: 'temp-${DateTime.now().millisecondsSinceEpoch}',
        missionText: _currentMission?.missionText ?? 'フォールバックミッション',
        matchId: widget.matchId,
        partnerUserId: widget.matchedUser.uid,
        partnerDisplayName: widget.matchedUser.displayName,
      );

      // 一時保存状態に変更
      await _missionStateService.temporarySaveMission();

      if (kDebugMode) {
        debugPrint('✅ ミッション一時保存完了');
      }

      // 成功ダイアログ表示
      if (mounted) {
        _showTemporarySaveSuccessDialog();
      }

    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 一時保存エラー: $e');
      }

      if (mounted) {
        _showErrorDialog('一時保存に失敗しました', e.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  /// 一時保存成功ダイアログ
  void _showTemporarySaveSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bookmark_added,
              color: Colors.orange.shade600,
              size: 60,
            ),
            const SizedBox(height: 16),
            const Text(
              'ミッションを保存しました',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'ホーム画面からいつでも続きを開始できます',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // ダイアログを閉じる
                Navigator.of(context).popUntil((route) => route.isFirst); // ホーム画面に戻る
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade500,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'ホームに戻る',
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

  /// エラーダイアログを表示
  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.red.shade600,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: Colors.red.shade800,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'OK',
              style: TextStyle(
                color: Colors.red.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.orange.shade50,
      appBar: AppBar(
        title: const Text(
          'コラボレーションミッション',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.orange.shade300,
        foregroundColor: Colors.white,
        elevation: 2,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: _isLoading ? _buildLoadingView() : _buildContent(),
      ),
    );
  }

  Widget _buildLoadingView() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
          ),
          SizedBox(height: 16),
          Text(
            'ミッションを生成中...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.orange,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_hasError) {
      return _buildErrorView();
    }

    if (_currentMission == null) {
      return _buildEmptyView();
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // パートナー情報
            _buildPartnerInfo(),

            const SizedBox(height: 16),

            // ミッション表示
            SlideTransition(
              position: _slideAnimation,
              child: _buildMissionCard(),
            ),

            const SizedBox(height: 16),

            // アクションボタン
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildPartnerInfo() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            // パートナーのアバター
            CircleAvatar(
              radius: 30,
              backgroundColor: Colors.orange.shade200,
              backgroundImage: (widget.matchedUser.profileImageUrl != null &&
                                widget.matchedUser.profileImageUrl!.isNotEmpty)
                  ? NetworkImage(widget.matchedUser.profileImageUrl!)
                  : null,
              child: (widget.matchedUser.profileImageUrl == null ||
                      widget.matchedUser.profileImageUrl!.isEmpty)
                  ? Icon(
                      Icons.person,
                      size: 30,
                      color: Colors.orange.shade600,
                    )
                  : null,
            ),

            const SizedBox(width: 16),

            // パートナー情報
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'コラボレーションパートナー',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.matchedUser.displayName.isNotEmpty
                        ? widget.matchedUser.displayName
                        : '匿名ユーザー',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  if (widget.matchedUser.location?.isNotEmpty == true) ...[
                    const SizedBox(height: 4),
                    Text(
                      widget.matchedUser.location!,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.orange.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // 接続アイコン
            Icon(
              Icons.handshake_outlined,
              color: Colors.orange.shade600,
              size: 28,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMissionCard() {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(
          minHeight: 300,
        ),
        padding: const EdgeInsets.all(20.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              Colors.orange.shade50,
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ミッションヘッダー
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.assignment_outlined,
                    color: Colors.orange.shade700,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currentMission!.isFallback
                            ? 'スタンダードミッション'
                            : 'AIカスタムミッション',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Text(
                        'あなたのミッション',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_currentMission!.isFallback)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'スタンダード',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 20),

            // ミッション内容
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.orange.shade200,
                  width: 2,
                ),
              ),
              child: Text(
                _currentMission!.missionText,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: 16),

            // ヒント・説明
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    color: Colors.blue.shade600,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'このミッションを通じて、お互いの専門分野や経験を共有し、新しいアイデアやコラボレーションの機会を見つけてください。',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.blue.shade700,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        // 一時保存ボタン
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton(
            onPressed: _isSaving ? null : _temporarySaveMission,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.orange.shade600,
              side: BorderSide(color: Colors.orange.shade400),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isSaving
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.orange.shade600),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        '保存中...',
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.bookmark_border, size: 20),
                      SizedBox(width: 8),
                      Text(
                        '一時保存して後で続ける',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
          ),
        ),

        const SizedBox(height: 12),

        // メインボタン：ミッション完了
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _goToFeedback,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade500,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline, size: 24),
                SizedBox(width: 12),
                Text(
                  'ミッション完了・フィードバック入力',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // サブボタン：ミッション再生成
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton(
            onPressed: _regenerateMission,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.orange.shade600,
              side: BorderSide(color: Colors.orange.shade400),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.refresh, size: 20),
                SizedBox(width: 8),
                Text(
                  '別のミッションを生成',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.shade400,
            ),
            const SizedBox(height: 16),
            const Text(
              'ミッション取得エラー',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? 'ミッションの取得に失敗しました',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadMission,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade500,
                foregroundColor: Colors.white,
              ),
              child: const Text('再試行'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView() {
    return const Center(
      child: Text(
        'ミッションが見つかりませんでした',
        style: TextStyle(
          fontSize: 16,
          color: Colors.grey,
        ),
      ),
    );
  }
}
