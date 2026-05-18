/// 用户模型
class User {
  final String userId;
  final String? nickname;
  final String? phone;
  final String? gender;
  final String? age;
  final bool showLocation;
  final bool isGuest;
  final int? matchRemaining;

  const User({
    required this.userId,
    this.nickname,
    this.phone,
    this.gender,
    this.age,
    this.showLocation = false,
    this.isGuest = false,
    this.matchRemaining,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      userId: json['userId'] ?? json['id'] ?? '',
      nickname: json['nickname'],
      phone: json['phone'],
      gender: json['gender'],
      age: json['age']?.toString(),
      showLocation: json['showLocation'] ?? false,
      isGuest: json['isGuest'] ?? false,
      matchRemaining: json['matchRemaining'],
    );
  }

  User copyWith({
    String? userId,
    String? nickname,
    String? phone,
    String? gender,
    String? age,
    bool? showLocation,
    bool? isGuest,
    int? matchRemaining,
  }) {
    return User(
      userId: userId ?? this.userId,
      nickname: nickname ?? this.nickname,
      phone: phone ?? this.phone,
      gender: gender ?? this.gender,
      age: age ?? this.age,
      showLocation: showLocation ?? this.showLocation,
      isGuest: isGuest ?? this.isGuest,
      matchRemaining: matchRemaining ?? this.matchRemaining,
    );
  }
}
