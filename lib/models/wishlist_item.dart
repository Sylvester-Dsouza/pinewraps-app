import 'package:flutter/material.dart';
import 'product.dart';

class WishlistItem {
  final String id;
  final Product product;
  final DateTime dateAdded;

  WishlistItem({
    required this.id,
    required this.product,
    required this.dateAdded,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product': product.toJson(),
      'dateAdded': dateAdded.toIso8601String(),
    };
  }

  factory WishlistItem.fromJson(Map<String, dynamic> json) {
    return WishlistItem(
      id: json['id'],
      product: Product.fromJson(json['product']),
      dateAdded: DateTime.parse(json['dateAdded']),
    );
  }
}
