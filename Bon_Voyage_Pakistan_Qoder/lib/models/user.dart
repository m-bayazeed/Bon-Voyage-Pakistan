/// User model for Bon Voyage Pakistan.
class User {
  final int id;
  final String name;
  final String email;

  const User({
    required this.id,
    required this.name,
    required this.email,
  });

  /// Create a User from the JSON map returned by the backend.
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      name: json['name'] as String,
      email: json['email'] as String,
    );
  }

  /// Convert to JSON (used for debugging / logging, never sends password).
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
      };
}
