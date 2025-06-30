enum MissionStatus {
  notAssigned,    // ミッション未割り当て
  assigned,       // ミッション割り当て済み・進行中
  temporarySaved, // 一時保存済み
  completed,      // ミッション完了
}

class MissionState {
  final String? missionId;
  final String? missionText;
  final String? matchId;
  final String? partnerUserId;
  final String? partnerDisplayName;
  final MissionStatus status;
  final DateTime? assignedAt;
  final DateTime? temporarySavedAt;
  final DateTime? completedAt;
  final String? feedbackText;

  const MissionState({
    this.missionId,
    this.missionText,
    this.matchId,
    this.partnerUserId,
    this.partnerDisplayName,
    required this.status,
    this.assignedAt,
    this.temporarySavedAt,
    this.completedAt,
    this.feedbackText,
  });

  factory MissionState.notAssigned() {
    return const MissionState(status: MissionStatus.notAssigned);
  }

  factory MissionState.assigned({
    required String missionId,
    required String missionText,
    required String matchId,
    required String partnerUserId,
    required String partnerDisplayName,
    required DateTime assignedAt,
  }) {
    return MissionState(
      missionId: missionId,
      missionText: missionText,
      matchId: matchId,
      partnerUserId: partnerUserId,
      partnerDisplayName: partnerDisplayName,
      status: MissionStatus.assigned,
      assignedAt: assignedAt,
    );
  }

  MissionState copyWith({
    String? missionId,
    String? missionText,
    String? matchId,
    String? partnerUserId,
    String? partnerDisplayName,
    MissionStatus? status,
    DateTime? assignedAt,
    DateTime? temporarySavedAt,
    DateTime? completedAt,
    String? feedbackText,
  }) {
    return MissionState(
      missionId: missionId ?? this.missionId,
      missionText: missionText ?? this.missionText,
      matchId: matchId ?? this.matchId,
      partnerUserId: partnerUserId ?? this.partnerUserId,
      partnerDisplayName: partnerDisplayName ?? this.partnerDisplayName,
      status: status ?? this.status,
      assignedAt: assignedAt ?? this.assignedAt,
      temporarySavedAt: temporarySavedAt ?? this.temporarySavedAt,
      completedAt: completedAt ?? this.completedAt,
      feedbackText: feedbackText ?? this.feedbackText,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'missionId': missionId,
      'missionText': missionText,
      'matchId': matchId,
      'partnerUserId': partnerUserId,
      'partnerDisplayName': partnerDisplayName,
      'status': status.name,
      'assignedAt': assignedAt?.toIso8601String(),
      'temporarySavedAt': temporarySavedAt?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'feedbackText': feedbackText,
    };
  }

  factory MissionState.fromJson(Map<String, dynamic> json) {
    return MissionState(
      missionId: json['missionId'],
      missionText: json['missionText'],
      matchId: json['matchId'],
      partnerUserId: json['partnerUserId'],
      partnerDisplayName: json['partnerDisplayName'],
      status: MissionStatus.values.firstWhere(
        (status) => status.name == (json['status'] ?? 'notAssigned'),
        orElse: () => MissionStatus.notAssigned,
      ),
      assignedAt: json['assignedAt'] != null
          ? DateTime.parse(json['assignedAt'])
          : null,
      temporarySavedAt: json['temporarySavedAt'] != null
          ? DateTime.parse(json['temporarySavedAt'])
          : null,
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'])
          : null,
      feedbackText: json['feedbackText'],
    );
  }

  // 便利なゲッター
  bool get isAssigned => status == MissionStatus.assigned;
  bool get isTemporarySaved => status == MissionStatus.temporarySaved;
  bool get isCompleted => status == MissionStatus.completed;
  bool get hasActiveMission => status == MissionStatus.assigned || status == MissionStatus.temporarySaved;
  bool get canShowMissionButton => hasActiveMission;
}
