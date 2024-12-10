class UserDetails {
  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final String phone;
  final String? imageUrl;
  final List<String>? addresses;
  final String? defaultAddress;

  UserDetails({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.phone,
    this.imageUrl,
    this.addresses,
    this.defaultAddress,
  });

  factory UserDetails.fromJson(Map<String, dynamic> json) {
    return UserDetails(
      id: json['_id'] ?? '',
      email: json['email'] ?? '',
      firstName: json['firstName'] ?? '',
      lastName: json['lastName'] ?? '',
      phone: json['phone'] ?? '',
      imageUrl: json['imageUrl'],
      addresses: json['addresses'] != null 
        ? List<String>.from(json['addresses'])
        : null,
      defaultAddress: json['defaultAddress'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'phone': phone,
      'imageUrl': imageUrl,
      'addresses': addresses,
      'defaultAddress': defaultAddress,
    };
  }
}
