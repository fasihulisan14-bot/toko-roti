class Customer {
  final int id;
  final String name;
  final String email;
  final String phone;
  final String address;
  final DateTime createdAt;

  Customer({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.address,
    required this.createdAt,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      address: json['address'] ?? '',
      createdAt: _parseDate(json['created_at']),
    );
  }

  static DateTime _parseDate(dynamic dateString) {
    if (dateString == null) return DateTime.now();

    try {
      String dateStr = dateString.toString();
      // Handle berbagai format tanggal
      if (dateStr.contains('T')) {
        // Format ISO: 2024-01-15T10:00:00Z
        return DateTime.parse(dateStr);
      } else if (dateStr.contains('GMT')) {
        // Format: Fri, 28 Nov 2025 16:49:18 GMT
        return DateTime.parse(dateStr.replaceAll(' GMT', ''));
      } else {
        // Default ke sekarang
        return DateTime.now();
      }
    } catch (e) {
      print('⚠️ Error parsing date: $dateString');
      return DateTime.now();
    }
  }
}
