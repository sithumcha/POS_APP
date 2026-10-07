class SubCategoryModel {
  final int? id;
  final int categoryId;
  final String name;
  final String slug;
  final String image;
  final String description;
  final String status;

  SubCategoryModel({
    this.id,
    required this.categoryId,
    required this.name,
    required this.slug,
    required this.image,
    required this.description,
    this.status = 'active',
  });

  factory SubCategoryModel.fromJson(Map<String, dynamic> json) {
    return SubCategoryModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? ''),
      categoryId: json['category_id'] is int
          ? json['category_id']
          : (int.tryParse(json['category_id']?.toString() ?? '') ??
              int.tryParse(json['categoryId']?.toString() ?? '') ??
              0),
      name: json['name']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      image: json['image']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      status: json['status']?.toString() ?? 'active',
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'category_id': categoryId,
      'name': name,
      'slug': slug,
      'image': image,
      'description': description,
      'status': status,
    };
    if (id != null) map['id'] = id;
    return map;
  }

  Map<String, dynamic> toRequestBody() {
    return {
      'category_id': categoryId,
      'name': name,
      'slug': slug,
      'image': image,
      'description': description,
      'status': status,
    };
  }
}
