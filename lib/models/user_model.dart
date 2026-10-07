class UserModel {
  final int? id;
  final String firstName;
  final String lastName;
  final String email;
  final String? password;

  UserModel({
    this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.password,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? ''),
      firstName: json['first_name']?.toString() ?? json['firstName']?.toString() ?? '',
      lastName: json['last_name']?.toString() ?? json['lastName']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toRegisterJson() {
    return {
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'password': password ?? '',
    };
  }

  Map<String, dynamic> toLoginJson() {
    return {
      'email': email,
      'password': password ?? '',
    };
  }
}
