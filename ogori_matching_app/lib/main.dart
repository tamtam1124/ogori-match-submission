import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
//import 'package:cloud_functions/cloud_functions.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/matching_screen.dart';
import 'test_mission_screen.dart';
import 'test_ai_profile_screen.dart';
import 'firebase_options.dart';

void main() async {
  if (kDebugMode) {
    print('🚀 アプリケーション開始');
  }

  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    if (kDebugMode) {
      print('✅ Firebase 初期化完了');
    }
  } catch (e) {
    if (kDebugMode) {
      print('❌ Firebase 初期化エラー: $e');
    }
  }

  if (kDebugMode) {
    print('🎯 MyApp 起動');
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OGORI MATCH',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      // ✅ 初期ルートを設定
      initialRoute: '/',
      // ✅ ルートテーブルを設定
      routes: {
        '/': (context) => const AuthWrapper(),
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/matching': (context) => const MatchingScreen(queueId: ''),
        '/test-mission': (context) => const TestMissionScreen(),
        '/test-ai-profile': (context) => const TestAiProfileScreen(),
      },
      // ✅ 不明なルートの処理
      onUnknownRoute: (settings) {
        return MaterialPageRoute(
          builder: (context) => const LoginScreen(),
        );
      },
    );
  }
}

// ✅ 認証状態を監視するラッパー
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // 認証状態の確認中
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // 認証済みの場合はホーム画面
        if (snapshot.hasData && snapshot.data != null) {
          final user = snapshot.data!; // ← ここは hasData && != null 後なので安全
          if (kDebugMode) {
            print('✅ 認証済みユーザー: ${user.uid}');
          }
          return kDebugMode ? const DebugHomeScreen() : const HomeScreen();
        }

        // 未認証の場合はログイン画面
        if (kDebugMode) {
          print('❌ 未認証状態');
        }
        return const LoginScreen();
      },
    );
  }
}

// 🔧 デバッグ用ホーム画面
class DebugHomeScreen extends StatelessWidget {
  const DebugHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DEBUG MODE'),
        backgroundColor: Colors.orange,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '🚀 デバッグモード',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // 通常のホーム画面へ
            ElevatedButton(
              onPressed: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const HomeScreen()),
              ),
              child: const Text('通常のアプリを開く'),
            ),

            const SizedBox(height: 16),

            // ミッション生成テスト
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TestMissionScreen()),
              ),
              child: const Text('🎯 ミッション生成テスト'),
            ),

            const SizedBox(height: 16),

            // ⭐ 追加：AIプロフィール生成テスト
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TestAiProfileScreen()),
              ),
              child: const Text('🤖 AIプロフィール生成テスト'),
            ),

            // 既存のデバッグテスト
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pushNamed(context, '/test-mission'),
              child: const Text('📋 既存ミッション機能テスト'),
            ),
          ],
        ),
      ),
    );
  }
}
