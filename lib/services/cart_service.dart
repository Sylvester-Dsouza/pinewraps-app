import 'dart:async';
import '../models/cart_item.dart';
import '../models/product.dart';

class CartService {
  static final CartService _instance = CartService._internal();
  factory CartService() => _instance;
  CartService._internal();

  final List<CartItem> _cartItems = [];
  final _cartController = StreamController<List<CartItem>>.broadcast();

  Stream<List<CartItem>> get cartStream => _cartController.stream;
  List<CartItem> get cartItems => List.unmodifiable(_cartItems);

  double get totalPrice {
    return _cartItems.fold(0, (total, item) => total + (item.price * item.quantity));
  }

  void addToCart({
    required Product product,
    required String selectedSize,
    required String selectedFlavour,
    required String cakeText,
    required int quantity,
  }) {
    final existingItemIndex = _cartItems.indexWhere(
      (item) =>
          item.product.id == product.id &&
          item.selectedSize == selectedSize &&
          item.selectedFlavour == selectedFlavour &&
          item.cakeText == cakeText,
    );

    if (existingItemIndex != -1) {
      // Update quantity if item exists
      _cartItems[existingItemIndex] = CartItem(
        id: _cartItems[existingItemIndex].id,
        product: product,
        selectedSize: selectedSize,
        selectedFlavour: selectedFlavour,
        cakeText: cakeText,
        quantity: _cartItems[existingItemIndex].quantity + quantity,
        price: product.getPriceForVariations(selectedSize, selectedFlavour),
      );
    } else {
      // Add new item
      _cartItems.add(
        CartItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          product: product,
          selectedSize: selectedSize,
          selectedFlavour: selectedFlavour,
          cakeText: cakeText,
          quantity: quantity,
          price: product.getPriceForVariations(selectedSize, selectedFlavour),
        ),
      );
    }

    _cartController.add(_cartItems);
  }

  void updateQuantity(String itemId, int quantity) {
    final index = _cartItems.indexWhere((item) => item.id == itemId);
    if (index != -1) {
      if (quantity <= 0) {
        _cartItems.removeAt(index);
      } else {
        _cartItems[index] = CartItem(
          id: _cartItems[index].id,
          product: _cartItems[index].product,
          selectedSize: _cartItems[index].selectedSize,
          selectedFlavour: _cartItems[index].selectedFlavour,
          cakeText: _cartItems[index].cakeText,
          quantity: quantity,
          price: _cartItems[index].price,
        );
      }
      _cartController.add(_cartItems);
    }
  }

  void removeFromCart(String itemId) {
    _cartItems.removeWhere((item) => item.id == itemId);
    _cartController.add(_cartItems);
  }

  void clearCart() {
    _cartItems.clear();
    _cartController.add(_cartItems);
  }

  void dispose() {
    _cartController.close();
  }
}
