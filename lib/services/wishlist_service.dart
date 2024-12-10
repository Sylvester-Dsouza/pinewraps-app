import 'dart:async';
import '../models/wishlist_item.dart';
import '../models/product.dart';

class WishlistService {
  static final WishlistService _instance = WishlistService._internal();
  factory WishlistService() => _instance;
  WishlistService._internal();

  final List<WishlistItem> _wishlistItems = [];
  final _wishlistController = StreamController<List<WishlistItem>>.broadcast();

  Stream<List<WishlistItem>> get wishlistStream => _wishlistController.stream;
  List<WishlistItem> get wishlistItems => List.unmodifiable(_wishlistItems);

  bool isInWishlist(String productId) {
    return _wishlistItems.any((item) => item.product.id == productId);
  }

  void addToWishlist(Product product) {
    if (!isInWishlist(product.id)) {
      final wishlistItem = WishlistItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        product: product,
        dateAdded: DateTime.now(),
      );
      _wishlistItems.add(wishlistItem);
      _wishlistController.add(_wishlistItems);
    }
  }

  void removeFromWishlist(String productId) {
    _wishlistItems.removeWhere((item) => item.product.id == productId);
    _wishlistController.add(_wishlistItems);
  }

  void toggleWishlist(Product product) {
    if (isInWishlist(product.id)) {
      removeFromWishlist(product.id);
    } else {
      addToWishlist(product);
    }
  }

  void dispose() {
    _wishlistController.close();
  }
}
