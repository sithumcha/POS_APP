class CategoryModel {
  final int? id;
  final int? userId;
  final String name;
  final String slug;
  final String image;
  final String description;
  final String status;
  final String? createdAt;
  final String? updatedAt;

  CategoryModel({
    this.id,
    this.userId,
    required this.name,
    required this.slug,
    required this.image,
    required this.description,
    this.status = 'active',
    this.createdAt,
    this.updatedAt,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? ''),
      userId: json['user_id'] is int ? json['user_id'] : int.tryParse(json['user_id']?.toString() ?? ''),
      name: json['name']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      image: json['image']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      status: json['status']?.toString() ?? 'active',
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'name': name,
      'slug': slug,
      'image': image,
      'description': description,
      'status': status,
    };
    if (id != null) map['id'] = id;
    if (userId != null) map['user_id'] = userId;
    if (createdAt != null) map['created_at'] = createdAt;
    if (updatedAt != null) map['updated_at'] = updatedAt;
    return map;
  }

  Map<String, dynamic> toRequestBody() {
    return {
      'name': name,
      'slug': slug,
      'image': image,
      'description': description,
      'status': status,
    };
  }
}
