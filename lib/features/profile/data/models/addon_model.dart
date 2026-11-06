class AddonModel {
  final String id;
  final String name;
  final String slug;
  final String type; // 'super_likes' or 'profile_boost'
  final num price;
  final num originalPrice;
  final num discountPercent;
  final int quantity;
  final int durationMinutes;
  final String description;
  final String? tag;
  final String icon;
  final bool isActive;
  final int displayOrder;

  const AddonModel({
    required this.id,
    required this.name,
    required this.slug,
    required this.type,
    required this.price,
    this.originalPrice = 0,
    this.discountPercent = 0,
    required this.quantity,
    this.durationMinutes = 0,
    this.description = '',
    this.tag,
    this.icon = 'Heart',
    this.isActive = true,
    this.displayOrder = 0,
  });

  bool get isSuperLikes => type == 'super_likes';
  bool get isProfileBoost => type == 'profile_boost';

  factory AddonModel.fromJson(Map<String, dynamic> json) {
    return AddonModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Addon',
      slug: json['slug']?.toString() ?? '',
      type: json['type']?.toString() ?? 'super_likes',
      price: json['price'] is num ? json['price'] as num : (num.tryParse(json['price']?.toString() ?? '0') ?? 0),
      originalPrice: json['originalPrice'] is num ? json['originalPrice'] as num : (num.tryParse(json['originalPrice']?.toString() ?? '0') ?? 0),
      discountPercent: json['discountPercent'] is num ? json['discountPercent'] as num : (num.tryParse(json['discountPercent']?.toString() ?? '0') ?? 0),
      quantity: json['quantity'] is int ? json['quantity'] as int : (int.tryParse(json['quantity']?.toString() ?? '1') ?? 1),
      durationMinutes: json['durationMinutes'] is int ? json['durationMinutes'] as int : (int.tryParse(json['durationMinutes']?.toString() ?? '0') ?? 0),
      description: json['description']?.toString() ?? '',
      tag: json['tag']?.toString(),
      icon: json['icon']?.toString() ?? 'Heart',
      isActive: json['isActive'] != false,
      displayOrder: json['displayOrder'] is int ? json['displayOrder'] as int : 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'type': type,
      'price': price,
      'originalPrice': originalPrice,
      'discountPercent': discountPercent,
      'quantity': quantity,
      'durationMinutes': durationMinutes,
      'description': description,
      'tag': tag,
      'icon': icon,
      'isActive': isActive,
      'displayOrder': displayOrder,
    };
  }
}

