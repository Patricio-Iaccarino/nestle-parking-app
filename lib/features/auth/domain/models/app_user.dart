class AppUser {
  final String uid;
  final String email;
  final String role; // 'superadmin', 'admin', 'user'

  AppUser({required this.uid, required this.email, required this.role});

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'email': email,
        'role': role,
      };

  factory AppUser.fromMap(Map<String, dynamic> map, String uid) {
    return AppUser(
      uid: uid,
      email: map['email'] ?? '',
      role: map['role'] ?? 'user',
    );
  }
}
