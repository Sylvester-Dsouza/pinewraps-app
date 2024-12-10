import 'dart:convert';

class ProductOption {
  final String id;
  final String value;
  final double priceAdjustment;
  final int stock;

  ProductOption({
    required this.id,
    required this.value,
    required this.priceAdjustment,
    required this.stock,
  });

  factory ProductOption.fromJson(Map<String, dynamic> json) {
    return ProductOption(
      id: json['id'] as String,
      value: json['value'] as String,
      priceAdjustment: (json['priceAdjustment'] as num).toDouble(),
      stock: json['stock'] as int,
    );
  }
}

class ProductVariation {
  final String id;
  final String type;
  final List<ProductOption> options;

  ProductVariation({
    required this.id,
    required this.type,
    required this.options,
  });

  factory ProductVariation.fromJson(Map<String, dynamic> json) {
    return ProductVariation(
      id: json['id'] as String,
      type: json['type'] as String,
      options: (json['options'] as List)
          .map((o) => ProductOption.fromJson(o as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ProductImage {
  final String id;
  final String url;
  final String alt;
  final bool isPrimary;

  ProductImage({
    required this.id,
    required this.url,
    required this.alt,
    required this.isPrimary,
  });

  factory ProductImage.fromJson(Map<String, dynamic> json) {
    try {
      return ProductImage(
        id: json['_id'] as String? ?? json['id'] as String? ?? '',
        url: json['url'] as String? ?? '',
        alt: json['alt'] as String? ?? '',
        isPrimary: json['isPrimary'] as bool? ?? false,
      );
    } catch (e, stackTrace) {
      print('Error parsing product image: $e');
      print('Stack trace: $stackTrace');
      print('JSON data: $json');
      rethrow;
    }
  }
}

class ProductCategory {
  final String id;
  final String name;

  ProductCategory({
    required this.id,
    required this.name,
  });

  factory ProductCategory.fromJson(Map<String, dynamic> json) {
    try {
      return ProductCategory(
        id: json['_id'] as String? ?? json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
      );
    } catch (e, stackTrace) {
      print('Error parsing product category: $e');
      print('Stack trace: $stackTrace');
      print('JSON data: $json');
      rethrow;
    }
  }
}

class Product {
  final String id;
  final String name;
  final String description;
  final String sku;
  final String status;
  final double basePrice;
  final String categoryId;
  final List<ProductVariation> variations;
  final List<ProductImage> images;
  final ProductCategory category;
  final List<Map<String, dynamic>> variantCombinations;

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.sku,
    required this.status,
    required this.basePrice,
    required this.categoryId,
    required this.variations,
    required this.images,
    required this.category,
    required this.variantCombinations,
  });

  String? get imageUrl => images.isNotEmpty ? images[0].url : null;

  List<String> get sizes {
    final sizeVariation = getVariationByType('SIZE');
    return sizeVariation?.options.map((o) => o.value).toList() ?? [];
  }

  List<String> get flavours {
    final flavourVariation = getVariationByType('FLAVOUR');
    return flavourVariation?.options.map((o) => o.value).toList() ?? [];
  }

  ProductVariation? getVariationByType(String type) {
    try {
      return variations.firstWhere(
        (v) => v.type == type,
      );
    } catch (e) {
      return null;
    }
  }

  double getPriceForVariations(String? size, String? flavour) {
    if (size == null || flavour == null) return basePrice;

    try {
      final combination = variantCombinations.firstWhere(
        (combo) =>
            combo['size'].toString() == size &&
            combo['flavour'].toString() == flavour,
      );
      return (combination['price'] as num).toDouble();
    } catch (e) {
      return basePrice;
    }
  }

  double get price => basePrice;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'sku': sku,
      'status': status,
      'basePrice': basePrice,
      'categoryId': categoryId,
      'category': {
        'id': category.id,
        'name': category.name,
      },
      'images': images.map((i) => {
        'id': i.id,
        'url': i.url,
        'alt': i.alt,
        'isPrimary': i.isPrimary,
      }).toList(),
      'variations': variations.map((v) => {
        'id': v.id,
        'type': v.type,
        'options': v.options.map((o) => {
          'id': o.id,
          'value': o.value,
          'priceAdjustment': o.priceAdjustment,
          'stock': o.stock,
        }).toList(),
      }).toList(),
      'variantCombinations': variantCombinations,
    };
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> parseCombinations(dynamic combinations) {
      if (combinations == null) return [];
      if (combinations is String) {
        try {
          final List<dynamic> parsed = jsonDecode(combinations);
          return List<Map<String, dynamic>>.from(parsed);
        } catch (e) {
          print('Error parsing variant combinations: $e');
          return [];
        }
      }
      if (combinations is List) {
        return List<Map<String, dynamic>>.from(combinations);
      }
      return [];
    }

    try {
      return Product(
        id: json['_id'] as String? ?? json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String? ?? '',
        sku: json['sku'] as String? ?? '',
        status: json['status'] as String? ?? 'active',
        basePrice: ((json['basePrice'] ?? json['price']) as num).toDouble(),
        categoryId: json['categoryId'] as String? ?? '',
        variations: json['variations'] != null
            ? (json['variations'] as List)
                .map((v) => ProductVariation.fromJson(v as Map<String, dynamic>))
                .toList()
            : [],
        images: json['images'] != null
            ? (json['images'] as List)
                .map((i) => ProductImage.fromJson(i as Map<String, dynamic>))
                .toList()
            : [],
        category: json['category'] != null
            ? ProductCategory.fromJson(json['category'] as Map<String, dynamic>)
            : ProductCategory(id: '', name: ''),
        variantCombinations: parseCombinations(json['variantCombinations']),
      );
    } catch (e, stackTrace) {
      print('Error parsing product: $e');
      print('Stack trace: $stackTrace');
      print('JSON data: $json');
      rethrow;
    }
  }
}
