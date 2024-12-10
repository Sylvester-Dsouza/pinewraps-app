class Address {
  final String? id;
  final String name;
  final String street;
  final String? apartment;
  final String city;
  final String state;
  final String postalCode;
  final String phoneNumber;
  final bool isDefault;

  Address({
    this.id,
    required this.name,
    required this.street,
    this.apartment,
    required this.city,
    required this.state,
    required this.postalCode,
    required this.phoneNumber,
    this.isDefault = false,
  });

  factory Address.fromJson(Map<String, dynamic> json) {
    return Address(
      id: json['_id'] as String?,
      name: json['name'] as String,
      street: json['street'] as String,
      apartment: json['apartment'] as String?,
      city: json['city'] as String,
      state: json['state'] as String,
      postalCode: json['postalCode'] as String,
      phoneNumber: json['phoneNumber'] as String,
      isDefault: json['isDefault'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) '_id': id,
      'name': name,
      'street': street,
      if (apartment != null) 'apartment': apartment,
      'city': city,
      'state': state,
      'postalCode': postalCode,
      'phoneNumber': phoneNumber,
      'isDefault': isDefault,
    };
  }

  Address copyWith({
    String? id,
    String? name,
    String? street,
    String? apartment,
    String? city,
    String? state,
    String? postalCode,
    String? phoneNumber,
    bool? isDefault,
  }) {
    return Address(
      id: id ?? this.id,
      name: name ?? this.name,
      street: street ?? this.street,
      apartment: apartment ?? this.apartment,
      city: city ?? this.city,
      state: state ?? this.state,
      postalCode: postalCode ?? this.postalCode,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      isDefault: isDefault ?? this.isDefault,
    );
  }
}
