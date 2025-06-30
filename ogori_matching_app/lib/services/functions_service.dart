// lib/services/functions_service.dart
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

class FunctionsService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// テスト用hello関数の呼び出し
  Future<Map<String, dynamic>> testHelloFunction() async {
    try {
      final HttpsCallable callable = _functions.httpsCallable('hello');
      final result = await callable.call();

      if (kDebugMode) {
        debugPrint('✅ Hello関数テスト成功: ${result.data}');
      }

      return result.data;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Hello関数テストエラー: $e');
      }
      rethrow;
    }
  }
}
