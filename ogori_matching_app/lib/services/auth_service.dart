import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'user_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final UserService _userService = UserService();

  User? get currentUser => _auth.currentUser;

  // メールアドレスでのアカウント作成（login_screenで使用される名前に合わせる）
  Future<UserCredential?> createAccountWithEmail(String email, String password) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        // 初期プロフィールを作成
        await _userService.createInitialProfile(credential.user!);
      }

      return credential;
    } catch (e) {
      throw Exception('アカウント作成に失敗しました: $e');
    }
  }

  // メールアドレスでのサインアップ（既存のメソッドも保持）
  Future<User?> signUpWithEmail(String email, String password) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        // 初期プロフィールを作成
        await _userService.createInitialProfile(credential.user!);
      }

      return credential.user;
    } catch (e) {
      throw Exception('サインアップに失敗しました: $e');
    }
  }

  // メールアドレスでのサインイン
  Future<User?> signInWithEmail(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        // プロフィールが存在しない場合は作成
        await _userService.createInitialProfile(credential.user!);
      }

      return credential.user;
    } catch (e) {
      throw Exception('サインインに失敗しました: $e');
    }
  }

  // Googleサインイン
  Future<User?> signInWithGoogle() async {
    try {
      // Googleサインインフローを開始
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // ユーザーがサインインをキャンセルした場合
        return null;
      }

      // 認証詳細をGoogleサインインアカウントから取得
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Firebaseの認証情報を作成
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Firebaseにサインイン
      final UserCredential userCredential = await _auth.signInWithCredential(credential);

      if (userCredential.user != null) {
        // プロフィールが存在しない場合は作成
        await _userService.createInitialProfile(userCredential.user!);
      }

      return userCredential.user;
    } catch (e) {
      throw Exception('Googleサインインに失敗しました: $e');
    }
  }

  // パスワードリセットメール送信
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      throw Exception('パスワードリセットメールの送信に失敗しました: $e');
    }
  }

  // パスワードリセット（既存のメソッド名も保持）
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      throw Exception('パスワードリセットに失敗しました: $e');
    }
  }

  // サインアウト
  Future<void> signOut() async {
    try {
      await Future.wait([
        _auth.signOut(),
        _googleSignIn.signOut(),
      ]);
    } catch (e) {
      throw Exception('サインアウトに失敗しました: $e');
    }
  }

  // 認証状態の変更を監視
  Stream<User?> get authStateChanges => _auth.authStateChanges();
}
