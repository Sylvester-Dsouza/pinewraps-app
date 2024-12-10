import 'package:flutter/foundation.dart';
import 'address.dart';

enum OrderStatus {
  all('All'),
  PENDING('Pending'),
  PROCESSING('Processing'),
  COMPLETED('Completed'),
  CANCELLED('Cancelled'),
  REFUNDED('Refunded');

  final String label;
  const OrderStatus(this.label);
}

class OrderItem {
  final String id;
  final String productId;
  final String name;
  final int quantity;
  final double price;
  final String? imageUrl;

  OrderItem({
    required this.id,
    required this.productId,
    required this.name,
    required this.quantity,
    required this.price,
    this.imageUrl,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'] as String,
      productId: json['productId'] as String,
      name: json['name'] as String,
      quantity: json['quantity'] as int,
      price: (json['price'] as num).toDouble(),
      imageUrl: json['imageUrl'] as String?,
    );
  }
}

class Order {
  final String id;
  final String orderNumber;
  final DateTime createdAt;
  final OrderStatus status;
  final List<OrderItem> items;
  final double total;
  final Address? deliveryAddress;

  Order({
    required this.id,
    required this.orderNumber,
    required this.createdAt,
    required this.status,
    required this.items,
    required this.total,
    this.deliveryAddress,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] as String,
      orderNumber: json['orderNumber'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      status: OrderStatus.values.firstWhere(
        (e) => e.name == (json['status'] as String),
        orElse: () => OrderStatus.PENDING,
      ),
      items: (json['items'] as List<dynamic>)
          .map((item) => OrderItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      total: (json['total'] as num).toDouble(),
      deliveryAddress: json['deliveryAddress'] != null
          ? Address.fromJson(json['deliveryAddress'] as Map<String, dynamic>)
          : null,
    );
  }
}
