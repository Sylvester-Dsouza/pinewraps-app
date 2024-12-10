import 'package:flutter/material.dart';
import '../../models/product.dart';
import '../../services/product_service.dart';
import '../../models/cart_item.dart';
import '../../models/wishlist_item.dart';
import '../../services/cart_service.dart';
import '../../services/wishlist_service.dart';
import '../cart/cart_screen.dart';
import '../../widgets/modern_notification.dart';

class ProductDetailsScreen extends StatefulWidget {
  final String productId;

  const ProductDetailsScreen({
    Key? key,
    required this.productId,
  }) : super(key: key);

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  final ProductService _productService = ProductService();
  final CartService _cartService = CartService();
  final WishlistService _wishlistService = WishlistService();
  final TextEditingController _cakeTextController = TextEditingController();
  bool _mounted = true;

  Product? _product;
  bool _isLoading = true;
  String? _error;
  String? _selectedSize;
  String? _selectedFlavour;

  @override
  void initState() {
    super.initState();
    _mounted = true;
    _loadProduct();
  }

  @override
  void dispose() {
    _mounted = false;
    _cakeTextController.dispose();
    super.dispose();
  }

  Future<void> _loadProduct() async {
    if (!_mounted) return;

    try {
      final product = await _productService.getProduct(widget.productId);
      if (!_mounted) return;

      setState(() {
        _product = product;
        _isLoading = false;
        
        // Set initial selections
        if (_product != null) {
          final flavours = _product!.flavours;
          if (flavours.isNotEmpty) {
            _selectedFlavour = flavours.first;
          }

          final sizes = _product!.sizes;
          if (sizes.isNotEmpty) {
            _selectedSize = sizes.first;
          }
        }
      });
    } catch (e) {
      if (!_mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  double _getPrice() {
    if (_product == null) return 0;
    
    // If product has no variations, return base price
    if (_product!.sizes.isEmpty && _product!.flavours.isEmpty) {
      return _product!.basePrice;
    }
    
    // If product has variations, get combination price
    final price = _product!.getPriceForVariations(_selectedSize, _selectedFlavour);
    return price > 0 ? price : _product!.basePrice;
  }

  Future<void> _addToCart() async {
    if (_product == null || !_mounted) return;

    // Only check for variations if they exist
    final hasVariations = _product!.sizes.isNotEmpty || _product!.flavours.isNotEmpty;
    final variationsSelected = !hasVariations || 
        (_product!.sizes.isEmpty || _selectedSize != null) && 
        (_product!.flavours.isEmpty || _selectedFlavour != null);

    if (!variationsSelected) {
      ModernNotification.show(
        context: context,
        message: 'Please select all required options',
        icon: Icons.error_outline_rounded,
        duration: const Duration(seconds: 2),
      );
      return;
    }

    _cartService.addToCart(
      product: _product!,
      selectedSize: _selectedSize ?? '',
      selectedFlavour: _selectedFlavour ?? '',
      cakeText: _cakeTextController.text.trim(),
      quantity: 1,
    );

    if (!_mounted) return;

    ModernNotification.show(
      context: context,
      message: 'Added to cart',
      actionLabel: 'VIEW CART',
      onActionPressed: () {
        if (!_mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const CartScreen(),
          ),
        );
      },
    );
  }

  Widget _buildSizeOption(String size) {
    final isSelected = _selectedSize == size;
    final sizeVariation = _product!.getVariationByType('SIZE');
    final sizeOption = sizeVariation?.options.firstWhere((o) => o.value == size);
    final priceAdjustment = sizeOption?.priceAdjustment ?? 0;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () {
          if (!_mounted) return;
          setState(() {
            _selectedSize = size;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color: isSelected ? Colors.black : Colors.white,
            border: Border.all(
              color: isSelected ? Colors.black : Colors.grey[300]!,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected ? [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ] : null,
          ),
          child: Column(
            children: [
              Text(
                size,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 15,
                ),
              ),
              if (priceAdjustment > 0) ...[
                const SizedBox(height: 4),
                Text(
                  '+${priceAdjustment.toStringAsFixed(0)} AED',
                  style: TextStyle(
                    color: isSelected ? Colors.white.withOpacity(0.8) : Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _product == null
                  ? const Center(child: Text('Product not found'))
                  : SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_product!.imageUrl != null)
                            Stack(
                              children: [
                                Image.network(
                                  _product!.imageUrl!,
                                  width: double.infinity,
                                  height: MediaQuery.of(context).size.height * 0.45,
                                  fit: BoxFit.cover,
                                ),
                                Positioned(
                                  top: MediaQuery.of(context).padding.top + 8,
                                  left: 16,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.9),
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: IconButton(
                                      icon: const Icon(Icons.arrow_back, size: 20),
                                      color: Colors.black,
                                      onPressed: () {
                                        if (!_mounted) return;
                                        Navigator.pop(context);
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(24),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, -5),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _product!.name,
                                              style: const TextStyle(
                                                fontSize: 24,
                                                fontWeight: FontWeight.bold,
                                                height: 1.2,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Starting from ${_product!.basePrice.toStringAsFixed(0)} AED',
                                              style: TextStyle(
                                                fontSize: 16,
                                                color: Colors.grey[600],
                                                height: 1.2,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[100],
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          _product!.category.name,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (_product!.description.isNotEmpty) ...[
                                    const SizedBox(height: 20),
                                    Text(
                                      _product!.description,
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        height: 1.5,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                  ],
                                  if (_product!.sizes.isNotEmpty) ...[
                                    Row(
                                      children: [
                                        const Text(
                                          'Select Size',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '(Required)',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Row(
                                        children: _product!.sizes.map((size) => _buildSizeOption(size)).toList(),
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                  ],
                                  if (_product!.flavours.isNotEmpty) ...[
                                    Row(
                                      children: [
                                        const Text(
                                          'Select Flavour',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '(Required)',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Container(
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: Colors.grey[300]!,
                                          width: 1,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButtonFormField<String>(
                                          value: _selectedFlavour,
                                          decoration: const InputDecoration(
                                            contentPadding: EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 12,
                                            ),
                                            border: InputBorder.none,
                                          ),
                                          items: _product!.flavours.map((flavour) {
                                            final flavourVariation = _product!.getVariationByType('FLAVOUR');
                                            final flavourOption = flavourVariation?.options
                                                .firstWhere((o) => o.value == flavour);
                                            final priceAdjustment = flavourOption?.priceAdjustment ?? 0;
                                            
                                            return DropdownMenuItem(
                                              value: flavour,
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text(
                                                    flavour,
                                                    style: const TextStyle(
                                                      fontSize: 15,
                                                    ),
                                                  ),
                                                  if (priceAdjustment > 0)
                                                    Text(
                                                      '+${priceAdjustment.toStringAsFixed(0)} AED',
                                                      style: TextStyle(
                                                        color: Colors.grey[600],
                                                        fontSize: 13,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                          onChanged: (value) {
                                            if (!_mounted) return;
                                            setState(() {
                                              _selectedFlavour = value;
                                            });
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 24),
                                  const Text(
                                    'Cake Text (Optional)',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: _cakeTextController,
                                    decoration: InputDecoration(
                                      hintText: 'Enter text for the cake',
                                      hintStyle: TextStyle(
                                        color: Colors.grey[400],
                                        fontSize: 15,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: Colors.grey[300]!,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: Colors.grey[300]!,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: Colors.black,
                                        ),
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
      bottomNavigationBar: _product == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    StreamBuilder<List<WishlistItem>>(
                      stream: _wishlistService.wishlistStream,
                      initialData: _wishlistService.wishlistItems,
                      builder: (context, snapshot) {
                        final isInWishlist = _product != null && 
                            _wishlistService.isInWishlist(_product!.id);
                        return Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.grey[300]!,
                              width: 1,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: IconButton(
                            icon: Icon(
                              isInWishlist ? Icons.favorite : Icons.favorite_border,
                              color: isInWishlist ? Colors.red : Colors.black,
                            ),
                            onPressed: _product == null
                                ? null
                                : () {
                                    if (!_mounted) return;
                                    _wishlistService.toggleWishlist(_product!);
                                    
                                    ModernNotification.show(
                                      context: context,
                                      message: isInWishlist
                                          ? 'Removed from wishlist'
                                          : 'Added to wishlist',
                                      icon: isInWishlist
                                          ? Icons.favorite_border
                                          : Icons.favorite,
                                      duration: const Duration(seconds: 2),
                                    );
                                  },
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _addToCart,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Add to Cart',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${_getPrice().toStringAsFixed(0)} AED',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
