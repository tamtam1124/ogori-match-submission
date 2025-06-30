/// AIが生成したミッション、またはフォールバックミッションのレスポンスを表すモデルクラス
class MissionResponse {
  /// ミッションのテキスト内容
  final String missionText;

  /// フォールバック（定型）ミッションかどうか
  final bool isFallback;

  /// ミッションの一意ID（オプション）
  final String? missionId;

  /// 生成日時（オプション）
  final DateTime? generatedAt;

  /// 参加者のユーザーIDリスト
  final List<String> participants;

  const MissionResponse({
    required this.missionText,
    required this.isFallback,
    this.missionId,
    this.generatedAt,
    this.participants = const [],
  });

  /// APIレスポンスのJSONからMissionResponseオブジェクトを生成
  factory MissionResponse.fromJson(Map<String, dynamic> json) {
    return MissionResponse(
      missionText: json['mission']['text'] as String,
      isFallback: json['metadata']?['isFallback'] ?? false,
      missionId: json['mission']?['id'] as String?,
      generatedAt: json['metadata']?['generatedAt'] != null
          ? DateTime.parse(json['metadata']['generatedAt'])
          : null,
      participants: json['mission']?['participants'] != null
          ? List<String>.from(json['mission']['participants'])
          : [],
    );
  }

  /// MissionResponseオブジェクトをJSONに変換
  Map<String, dynamic> toJson() {
    return {
      'mission': {
        'text': missionText,
        'id': missionId,
        'participants': participants,
      },
      'metadata': {
        'isFallback': isFallback,
        'generatedAt': generatedAt?.toIso8601String(),
      },
    };
  }

  /// デバッグ用の文字列表現
  @override
  String toString() {
    return 'MissionResponse{missionText: $missionText, isFallback: $isFallback, missionId: $missionId}';
  }

  /// オブジェクトの等価性を判定
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MissionResponse &&
          runtimeType == other.runtimeType &&
          missionText == other.missionText &&
          isFallback == other.isFallback &&
          missionId == other.missionId &&
          _listEquals(participants, other.participants);

  @override
  int get hashCode =>
      missionText.hashCode ^
      isFallback.hashCode ^
      missionId.hashCode ^
      participants.hashCode;

  /// リスト比較のヘルパーメソッド
  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// テスト用のダミーデータを生成するファクトリーメソッド
  factory MissionResponse.dummy({
    String? customText,
    bool isFallback = false,
    List<String>? participants,
  }) {
    return MissionResponse(
      missionText: customText ?? '仕事で一番やりがいを感じる瞬間について話し合ってください。',
      isFallback: isFallback,
      missionId: 'dummy-mission-${DateTime.now().millisecondsSinceEpoch}',
      generatedAt: DateTime.now(),
      participants: participants ?? ['current-user', 'partner-user'],
    );
  }

  /// 参加者数の取得
  int get participantCount => participants.length;

  /// 特定のユーザーが参加者に含まれているかチェック
  bool hasParticipant(String userId) => participants.contains(userId);

  /// 参加者名を表示用にフォーマット
  String get participantsText {
    if (participants.isEmpty) return '参加者なし';
    if (participants.length == 1) return '参加者: ${participants.first}';
    return '参加者: ${participants.join(', ')}';
  }
}
