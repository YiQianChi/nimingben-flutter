/// 匹配结果模型
class MatchResult {
  final String roomId;
  final PartnerInfo partner;

  const MatchResult({required this.roomId, required this.partner});

  factory MatchResult.fromJson(Map<String, dynamic> json) {
    return MatchResult(
      roomId: json['roomId'] ?? '',
      partner: PartnerInfo.fromJson(json['partner'] ?? {}),
    );
  }
}

/// 对方信息
class PartnerInfo {
  final String? nickname;
  final String? userId;
  final String? gender;
  final String? age;
  final String? location;
  final List<String>? tags;

  const PartnerInfo({
    this.nickname,
    this.userId,
    this.gender,
    this.age,
    this.location,
    this.tags,
  });

  factory PartnerInfo.fromJson(Map<String, dynamic> json) {
    return PartnerInfo(
      nickname: json['nickname'],
      userId: json['userId'],
      gender: json['gender'],
      age: json['age']?.toString(),
      location: json['location'],
      tags: (json['tags'] as List?)?.map((e) => e.toString()).toList(),
    );
  }

  /// 性别显示文本
  String get genderText {
    switch (gender) {
      case 'male':
        return '男';
      case 'female':
        return '女';
      default:
        return '未知';
    }
  }
}
