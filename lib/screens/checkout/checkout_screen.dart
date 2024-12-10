import 'package:flutter/material.dart';
import '../../services/cart_service.dart';
import '../../services/api_service.dart';
import '../../models/address.dart';

enum DeliveryMethod { storePickup, standardDelivery }

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({Key? key}) : super(key: key);

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final CartService _cartService = CartService();
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();
  
  // Form fields
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _streetController = TextEditingController();
  final _apartmentController = TextEditingController();
  final _cityController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _couponController = TextEditingController();
  final _giftMessageController = TextEditingController();
  
  // UAE Emirates
  final List<String> _emirates = [
    'Abu Dhabi',
    'Dubai',
    'Sharjah',
    'Ajman',
    'Umm Al Quwain',
    'Ras Al Khaimah',
    'Fujairah',
  ];
  String? _selectedEmirate;
  double _deliveryCharge = 0;
  
  // Define emirates list and their corresponding time slots
  final Map<String, List<String>> _emirateTimeSlots = {
    'Dubai': [
      '9:00 AM - 11:00 AM',
      '11:00 AM - 1:00 PM',
      '1:00 PM - 3:00 PM',
      '3:00 PM - 5:00 PM',
      '5:00 PM - 7:00 PM',
    ],
    'Abu Dhabi': [
      '10:00 AM - 2:00 PM',
      '2:00 PM - 6:00 PM',
    ],
    'Sharjah': [
      '10:00 AM - 2:00 PM',
      '2:00 PM - 6:00 PM',
    ],
    'Ajman': [
      '10:00 AM - 2:00 PM',
      '2:00 PM - 6:00 PM',
    ],
    'Ras Al Khaimah': [
      '10:00 AM - 2:00 PM',
      '2:00 PM - 6:00 PM',
    ],
    'Fujairah': [
      '10:00 AM - 2:00 PM',
      '2:00 PM - 6:00 PM',
    ],
    'Umm Al Quwain': [
      '10:00 AM - 2:00 PM',
      '2:00 PM - 6:00 PM',
    ],
  ];

  DeliveryMethod _deliveryMethod = DeliveryMethod.storePickup;
  DateTime? _selectedDate;
  String? _selectedTimeSlot;
  bool _isGift = false;
  bool _appliedCoupon = false;
  bool _isLoading = true;
  List<Address> _savedAddresses = [];
  Address? _selectedAddress;

  // Add new variables for price breakdown
  double _pointsValue = 0;
  String? _couponCode;
  double _couponDiscount = 0;
  bool _isPointsRedeemed = false;
  static const int POINTS_TO_REDEEM = 100; // Static for now
  static const double POINTS_VALUE = 10; // 10 AED for 100 points

  @override
  void initState() {
    super.initState();
    _loadUserDetails();
    _loadSavedAddresses();
  }

  Future<void> _loadUserDetails() async {
    try {
      setState(() => _isLoading = true);
      final userData = await _apiService.getCurrentUser();
      
      setState(() {
        _nameController.text = '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'.trim();
        _emailController.text = userData['email'] ?? '';
        _phoneController.text = userData['phone'] ?? '';
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load user details')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadSavedAddresses() async {
    try {
      final addresses = await _apiService.getAddresses();
      setState(() {
        _savedAddresses = addresses;
        // Set default address if available
        if (addresses.isNotEmpty) {
          _selectedAddress = addresses.firstWhere(
            (addr) => addr.isDefault,
            orElse: () => addresses.first,
          );
          _updateShippingFields(_selectedAddress!);
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load saved addresses')),
      );
    }
  }

  void _updateShippingFields(Address address) {
    _streetController.text = address.street;
    _apartmentController.text = address.apartment ?? '';
    _cityController.text = address.city;
    _selectedEmirate = address.state;
    _pincodeController.text = address.postalCode;
  }

  void _updateDeliveryCharge(String? emirate) {
    setState(() {
      _selectedEmirate = emirate;
      _selectedTimeSlot = null; // Reset time slot when emirate changes
      _deliveryCharge = emirate == 'Dubai' ? 30 : 40;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _streetController.dispose();
    _apartmentController.dispose();
    _cityController.dispose();
    _pincodeController.dispose();
    _couponController.dispose();
    _giftMessageController.dispose();
    super.dispose();
  }

  double get _subtotal => _cartService.totalPrice;
  double get _total => _calculateTotal();

  double _calculateTotal() {
    double total = _subtotal;
    
    // Add delivery charge if applicable
    if (_deliveryMethod == DeliveryMethod.standardDelivery) {
      total += _deliveryCharge;
    }
    
    // Subtract points value if redeemed
    if (_isPointsRedeemed) {
      total -= _pointsValue;
    }
    
    // Subtract coupon discount if applied
    if (_couponCode != null) {
      total -= _couponDiscount;
    }
    
    return total;
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(
        Duration(days: _deliveryMethod == DeliveryMethod.storePickup ? 7 : 30),
      ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.black,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        // Reset time slot when date changes
        _selectedTimeSlot = null;
      });
    }
  }

  Widget _buildTimeSlotSelector() {
    List<String> timeSlots;
    if (_deliveryMethod == DeliveryMethod.storePickup) {
      timeSlots = [
        '10:00 AM',
        '11:00 AM',
        '12:00 PM',
        '1:00 PM',
        '2:00 PM',
        '3:00 PM',
        '4:00 PM',
        '5:00 PM',
        '6:00 PM',
        '7:00 PM',
        '8:00 PM',
        '9:00 PM',
      ];
    } else {
      // Show emirate-specific time slots or empty list if no emirate selected
      timeSlots = _selectedEmirate != null 
          ? _emirateTimeSlots[_selectedEmirate]!
          : [];
    }

    // Reset selected time slot if it's not in the current list of time slots
    if (_selectedTimeSlot != null && !timeSlots.contains(_selectedTimeSlot)) {
      _selectedTimeSlot = null;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        if (_deliveryMethod == DeliveryMethod.standardDelivery && _selectedEmirate != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              'Delivery Charge: ${_deliveryCharge.toStringAsFixed(0)} AED',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        DropdownButtonFormField<String>(
          value: _selectedTimeSlot,
          decoration: InputDecoration(
            labelText: _deliveryMethod == DeliveryMethod.storePickup
                ? 'Select Pickup Time'
                : 'Select Delivery Time',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.black),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          items: timeSlots.map((slot) => DropdownMenuItem(
                value: slot,
                child: Text(slot),
              )).toList(),
          onChanged: (value) {
            setState(() {
              _selectedTimeSlot = value;
            });
          },
          validator: (value) {
            if (_deliveryMethod == DeliveryMethod.standardDelivery && _selectedEmirate == null) {
              return 'Please select an emirate first';
            }
            return value == null
                ? _deliveryMethod == DeliveryMethod.storePickup
                    ? 'Please select a pickup time'
                    : 'Please select a delivery time'
                : null;
          },
        ),
      ],
    );
  }

  Widget _buildShippingForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_savedAddresses.isNotEmpty) ...[
          const Text(
            'Select a Saved Address',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonFormField<Address>(
              value: _selectedAddress,
              decoration: InputDecoration(
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              items: _savedAddresses.map((address) {
                return DropdownMenuItem(
                  value: address,
                  child: Text('${address.street}, ${address.city}'),
                );
              }).toList(),
              onChanged: (Address? value) {
                setState(() {
                  _selectedAddress = value;
                  if (value != null) {
                    _updateShippingFields(value);
                  }
                });
              },
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Or Enter a New Address',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
        ],
        _buildTextField(
          controller: _streetController,
          label: 'Street Address',
          maxLines: 2,
          validator: (value) =>
              value?.isEmpty ?? true ? 'Please enter your street address' : null,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _apartmentController,
          label: 'Apartment / Area',
          maxLines: 1,
          validator: (value) =>
              value?.isEmpty ?? true ? 'Please enter your apartment/area' : null,
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _selectedEmirate,
          decoration: InputDecoration(
            labelText: 'Emirates',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          items: _emirates.map((emirate) {
            return DropdownMenuItem(
              value: emirate,
              child: Text(emirate),
            );
          }).toList(),
          onChanged: _updateDeliveryCharge,
          validator: (value) =>
              value == null ? 'Please select an emirate' : null,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _cityController,
          label: 'City',
          validator: (value) =>
              value?.isEmpty ?? true ? 'Please enter your city' : null,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _pincodeController,
          label: 'Pincode',
          keyboardType: TextInputType.number,
          validator: (value) =>
              value?.isEmpty ?? true ? 'Please enter your pincode' : null,
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
    bool enabled = true,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.black),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        filled: !enabled,
        fillColor: enabled ? null : Colors.grey[100],
      ),
      validator: validator,
    );
  }

  Widget _buildDeliveryMethodCard(
    DeliveryMethod method,
    String title,
    String subtitle,
    IconData icon,
  ) {
    final isSelected = _deliveryMethod == method;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? Colors.black : Colors.grey[300]!,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          setState(() {
            _deliveryMethod = method;
            // Clear selected time slot when delivery method changes
            _selectedTimeSlot = null;
            _selectedDate = null;
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                icon,
                size: 24,
                color: isSelected ? Colors.black : Colors.grey[600],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? Colors.black : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                const Icon(
                  Icons.check_circle,
                  color: Colors.black,
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Method to toggle points redemption
  void _togglePointsRedemption() {
    setState(() {
      _isPointsRedeemed = !_isPointsRedeemed;
      _pointsValue = _isPointsRedeemed ? POINTS_VALUE : 0;
    });
  }

  // Method to apply coupon
  void _applyCoupon(String code) {
    // For now, static 10% discount
    setState(() {
      _couponCode = code;
      _couponDiscount = _subtotal * 0.1; // 10% discount
    });
  }

  // Build the price breakdown section
  Widget _buildPriceBreakdown() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[300]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Price Breakdown',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildPriceRow('Subtotal', _subtotal),
            if (_deliveryMethod == DeliveryMethod.standardDelivery)
              _buildPriceRow('Delivery Charge', _deliveryCharge),
            if (_isPointsRedeemed)
              _buildPriceRow(
                'Points Redeemed ($POINTS_TO_REDEEM points)',
                -_pointsValue,
                isDeduction: true,
              ),
            if (_couponCode != null)
              _buildPriceRow(
                'Coupon Discount ($_couponCode)',
                -_couponDiscount,
                isDeduction: true,
              ),
            const Divider(height: 24),
            _buildPriceRow(
              'Total',
              _calculateTotal(),
              isTotal: true,
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to build price rows
  Widget _buildPriceRow(String label, double amount,
      {bool isDeduction = false, bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            '${isDeduction ? '-' : ''}${amount.toStringAsFixed(2)} AED',
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isDeduction ? Colors.red : null,
            ),
          ),
        ],
      ),
    );
  }

  // Add points redemption section
  Widget _buildPointsRedemption() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[300]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Redeem Points',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Use $POINTS_TO_REDEEM points to get $POINTS_VALUE AED off',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: _isPointsRedeemed,
              onChanged: (_) => _togglePointsRedemption(),
              activeColor: Colors.black,
            ),
          ],
        ),
      ),
    );
  }

  // Add coupon section
  Widget _buildCouponSection() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[300]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Have a Coupon?',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    decoration: InputDecoration(
                      hintText: 'Enter coupon code',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onFieldSubmitted: _applyCoupon,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _applyCoupon('SAVE10'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  child: const Text('Apply'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Checkout',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Contact Information
            _buildSectionTitle('Contact Information'),
            _buildTextField(
              controller: _nameController,
              label: 'Full Name',
              enabled: false,
              validator: (value) =>
                  value?.isEmpty ?? true ? 'Please enter your name' : null,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _emailController,
              label: 'Email',
              enabled: false,
              keyboardType: TextInputType.emailAddress,
              validator: (value) =>
                  value?.isEmpty ?? true ? 'Please enter your email' : null,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _phoneController,
              label: 'Phone Number',
              keyboardType: TextInputType.phone,
              validator: (value) =>
                  value?.isEmpty ?? true ? 'Please enter your phone number' : null,
            ),
            const SizedBox(height: 24),

            // Delivery Method
            _buildSectionTitle('Delivery Method'),
            _buildDeliveryMethodCard(
              DeliveryMethod.storePickup,
              'Store Pickup',
              'Pick up your order from our store',
              Icons.store,
            ),
            const SizedBox(height: 12),
            _buildDeliveryMethodCard(
              DeliveryMethod.standardDelivery,
              'Standard Delivery',
              'Delivery to your address',
              Icons.local_shipping,
            ),
            const SizedBox(height: 24),

            // Shipping Address (only show if standard delivery is selected)
            if (_deliveryMethod == DeliveryMethod.standardDelivery) ...[
              _buildSectionTitle('Shipping Address'),
              _buildShippingForm(),
              const SizedBox(height: 24),
            ],

            // Delivery Date and Time
            _buildSectionTitle(_deliveryMethod == DeliveryMethod.storePickup
                ? 'Pickup Date & Time'
                : 'Delivery Date & Time'),
            InkWell(
              onTap: () => _selectDate(context),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today),
                    const SizedBox(width: 16),
                    Text(
                      _selectedDate != null
                          ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                          : 'Select Date',
                      style: TextStyle(
                        color: _selectedDate != null
                            ? Colors.black
                            : Colors.grey[600],
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_selectedDate != null) _buildTimeSlotSelector(),
            const SizedBox(height: 24),

            // Gift Option
            _buildSectionTitle('Gift Options'),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Send this as a gift',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'We\'ll include a gift message card with your order',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _isGift,
                          onChanged: (value) {
                            setState(() {
                              _isGift = value;
                              if (!value) {
                                _giftMessageController.clear();
                              }
                            });
                          },
                          activeColor: Colors.black,
                        ),
                      ],
                    ),
                  ),
                  if (_isGift) ...[
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Gift Message',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _giftMessageController,
                            maxLines: 3,
                            maxLength: 200,
                            decoration: InputDecoration(
                              hintText: 'Write your gift message here...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Colors.black),
                              ),
                              filled: true,
                              fillColor: Colors.grey[50],
                            ),
                            validator: (value) {
                              if (_isGift && (value == null || value.isEmpty)) {
                                return 'Please enter a gift message';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Coupon
            _buildSectionTitle('Have a Coupon?'),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _couponController,
                    decoration: InputDecoration(
                      hintText: 'Enter coupon code',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                    enabled: !_appliedCoupon,
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _appliedCoupon
                      ? null
                      : () {
                          // TODO: Implement coupon validation
                          setState(() {
                            _appliedCoupon = true;
                          });
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(_appliedCoupon ? 'Applied' : 'Apply'),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Order Summary
            _buildSectionTitle('Order Summary'),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Subtotal'),
                Text('${_subtotal.toStringAsFixed(0)} AED'),
              ],
            ),
            const Divider(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                Text(
                  '${_total.toStringAsFixed(0)} AED',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildPointsRedemption(),
            const SizedBox(height: 24),
            _buildCouponSection(),
            const SizedBox(height: 24),
            _buildPriceBreakdown(),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: () {
              if (_formKey.currentState?.validate() ?? false) {
                // TODO: Process the order
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Place Order (Cash on Delivery)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
