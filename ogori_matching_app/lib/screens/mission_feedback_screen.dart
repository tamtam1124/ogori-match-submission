import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/mission_service.dart';
import '../services/mission_state_service.dart';

class MissionFeedbackScreen extends StatefulWidget {
  final String matchId;
  final String missionText;
  final String? partnerUserId;

  const MissionFeedbackScreen({
    Key? key,
    required this.matchId,
    required this.missionText,
    this.partnerUserId,
  }) : super(key: key);

  @override
  State<MissionFeedbackScreen> createState() => _MissionFeedbackScreenState();
}

class _MissionFeedbackScreenState extends State<MissionFeedbackScreen> {
  final TextEditingController _feedbackController = TextEditingController();
  final MissionService _missionService = MissionService();
  final MissionStateService _missionStateService = MissionStateService();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _submitFeedback() async {
    final feedback = _feedbackController.text.trim();

    if (feedback.isEmpty) {
      _showErrorDialog('フィードバックを入力してください');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await _missionService.submitFeedback(
        matchId: widget.matchId,
        feedback: feedback,
        partnerUserId: widget.partnerUserId,
      );

      // ミッション完了状態に更新
      await _missionStateService.completeMission(feedback);

      if (kDebugMode) {
        debugPrint('✅ ミッション完了状態に更新');
      }

      if (mounted) {
        _showSuccessDialog();
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('フィードバックの送信に失敗しました: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
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
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('送信完了'),
        content: const Text('フィードバックを送信しました！\nお疲れさまでした。'),
        actions: [
          TextButton(
            onPressed: () async {
              // ダイアログを閉じる
              Navigator.of(dialogContext).pop();

              // 少し待ってからホーム画面に戻る（状態更新を確実にするため）
              await Future.delayed(const Duration(milliseconds: 500));

              // 元のcontextが有効な場合のみ実行
              if (mounted) {
                // BuildContextをキャプチャして使用
                final navigator = Navigator.of(context);
                navigator.popUntil((route) => route.isFirst);
              }
            },
            child: const Text('完了'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('ミッションフィードバック'),
        backgroundColor: Colors.orange[300],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ミッション表示
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '完了したミッション',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.missionText,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // フィードバック入力
            const Text(
              'フィードバック',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'ミッションを通じて感じたことや、相手とのコミュニケーションについて教えてください。',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 12),

            // テキスト入力フィールド
            SizedBox(
              height: 200,
              child: TextField(
                controller: _feedbackController,
                maxLines: null,
                expands: true,
                decoration: const InputDecoration(
                  hintText: 'フィードバックを入力してください...\n\n例：\n・相手の話を聞いて新しい発見がありました\n・今度また話してみたいと思いました',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                textAlignVertical: TextAlignVertical.top,
              ),
            ),

            const SizedBox(height: 24),

            // 送信ボタン
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitFeedback,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[400],
                  foregroundColor: Colors.white,
                ),
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'フィードバックを送信',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
