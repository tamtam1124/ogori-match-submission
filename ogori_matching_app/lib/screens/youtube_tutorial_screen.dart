import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:ui_web' as ui;
import 'package:web/web.dart' as web;

class YouTubeTutorialScreen extends StatefulWidget {
  const YouTubeTutorialScreen({Key? key}) : super(key: key);

  @override
  State<YouTubeTutorialScreen> createState() => _YouTubeTutorialScreenState();
}

class _YouTubeTutorialScreenState extends State<YouTubeTutorialScreen> {
  late String viewId;

  @override
  void initState() {
    super.initState();
    viewId = 'video-player-${DateTime.now().millisecondsSinceEpoch}';
    if (kIsWeb) {
      _registerVideoPlayer();
    }
  }

  void _registerVideoPlayer() {
    if (!kIsWeb) return;

    const videoUrl = 'https://firebasestorage.googleapis.com/v0/b/engineeringu.firebasestorage.app/o/tutorial%2FOGORI_MATCH_%E5%8B%95%E7%94%BB%E3%81%AE%E3%82%B3%E3%83%94%E3%83%BC.mp4?alt=media&token=fa5c7022-590e-49f6-9a11-228ef64f091e';

    final videoElement = web.HTMLVideoElement()
      ..src = videoUrl
      ..controls = true
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.objectFit = 'cover';

    // ignore: undefined_prefixed_name
    ui.platformViewRegistry.registerViewFactory(viewId, (int viewId) => videoElement);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.95,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ヘッダー
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "📱 おごりマッチの使い方",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // 動画プレイヤー
            SizedBox(
              height: 250,
              child: kIsWeb
                  ? _buildWebVideoPlayer()
                  : _buildMobileVideoPlayer(),
            ),

            // 説明テキスト
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text(
                    "🎯 マッチング → 💬 ミッション → 👤 プロフィール",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "動画でアプリの使い方を分かりやすく解説しています。",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black54,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text("始めてみる！"),
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

  Widget _buildWebVideoPlayer() {
    return SizedBox(
      width: double.infinity,
      child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        child: HtmlElementView(viewType: viewId),
      ),
    );
  }

  Widget _buildMobileVideoPlayer() {
    return const Center(
      child: Text(
        'モバイル版では動画プレイヤーをサポートしていません',
        textAlign: TextAlign.center,
      ),
    );
  }
}
