class Product {
  final int id;
  final String name;
  final String description;
  final double price;
  final int stock;
  final String category;
  final String imageUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.stock,
    required this.category,
    required this.imageUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      stock: json['stock'] ?? 0,
      category: json['category'] ?? '',
      imageUrl: json['image_url'] ?? '',
      createdAt: _parseDate(json['created_at']), // FIX: Pakai function parser
      updatedAt: _parseDate(json['updated_at']), // FIX: Pakai function parser
    );
  }

  // FIX: Function untuk parse berbagai format tanggal
  static DateTime _parseDate(dynamic dateString) {
    if (dateString == null) return DateTime.now();

    try {
      // Coba parse sebagai DateTime langsung
      if (dateString is DateTime) return dateString;

      String dateStr = dateString.toString();

      // Handle format: "Fri, 28 Nov 2025 16:49:18 GMT"
      if (dateStr.contains('GMT')) {
        return DateTime.parse(dateStr.replaceAll(' GMT', ''));
      }

      // Handle format ISO standard
      return DateTime.parse(dateStr);
    } catch (e) {
      print('⚠️ Error parsing date: $dateString, using current date');
      return DateTime.now();
    }
  }
}
