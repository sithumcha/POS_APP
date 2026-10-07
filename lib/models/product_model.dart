class ProductModel {
  final int? id;
  final int categoryId;
  final int subcategoryId;
  final String name;
  final String sku;
  final double price;
  final double? discountPrice;
  final int stock;
  final String status;
  final bool featured;
  final String shortDescription;
  final String fullDescription;
  final String mainImage;
  final List<String> images;
  final List<String> tags;
  final List<dynamic> variations;

  ProductModel({
    this.id,
    required this.categoryId,
    required this.subcategoryId,
    required this.name,
    required this.sku,
    required this.price,
    this.discountPrice,
    required this.stock,
    this.status = 'active',
    this.featured = false,
    required this.shortDescription,
    required this.fullDescription,
    required this.mainImage,
    this.images = const [],
    this.tags = const [],
    this.variations = const [],
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? ''),
      categoryId: json['category_id'] is int
          ? json['category_id']
          : (int.tryParse(json['category_id']?.toString() ?? '') ?? 0),
      subcategoryId: json['subcategory_id'] is int
          ? json['subcategory_id']
          : (int.tryParse(json['subcategory_id']?.toString() ?? '') ?? 0),
      name: json['name']?.toString() ?? '',
      sku: json['sku']?.toString() ?? '',
      price: (json['price'] is num)
          ? (json['price'] as num).toDouble()
          : (double.tryParse(json['price']?.toString() ?? '') ?? (json['base_price'] is num ? (json['base_price'] as num).toDouble() : 0.0)),
      discountPrice: json['discount_price'] != null
          ? ((json['discount_price'] is num)
              ? (json['discount_price'] as num).toDouble()
              : double.tryParse(json['discount_price'].toString()))
          : null,
      stock: json['stock'] is int
          ? json['stock']
          : (int.tryParse(json['stock']?.toString() ?? '') ?? 0),
      status: json['status']?.toString() ?? 'active',
      featured: json['featured'] is bool ? json['featured'] : (json['featured']?.toString() == 'true'),
      shortDescription: json['short_description']?.toString() ?? '',
      fullDescription: json['full_description']?.toString() ?? '',
      mainImage: json['main_image']?.toString() ?? '',
      images: json['images'] is List ? (json['images'] as List).map((e) => e.toString()).toList() : [],
      tags: json['tags'] is List ? (json['tags'] as List).map((e) => e.toString()).toList() : [],
      variations: json['variations'] is List ? (json['variations'] as List) : [],
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'category_id': categoryId,
      'subcategory_id': subcategoryId,
      'name': name,
      'sku': sku,
      'price': price,
      'discount_price': discountPrice,
      'stock': stock,
      'status': status,
      'featured': featured,
      'short_description': shortDescription,
      'full_description': fullDescription,
      'main_image': mainImage,
      'images': images,
      'tags': tags,
      'variations': variations,
    };
    if (id != null) map['id'] = id;
    return map;
  }

  Map<String, dynamic> toRequestBody() {
    return {
      'category_id': categoryId,
      'subcategory_id': subcategoryId,
      'name': name,
      'sku': sku,
      'price': price,
      'discount_price': discountPrice,
      'stock': stock,
      'status': status,
      'featured': featured,
      'short_description': shortDescription,
      'full_description': fullDescription,
      'main_image': mainImage,
      'images': images,
      'tags': tags,
      'variations': variations,
    };
  }
}
