import 'package:flutter/material.dart';
import '../payment/payment_screen.dart';
import '../../services/cart_service.dart';
import '../../services/api_service.dart';
import '../../services/payment_service.dart';
import '../../models/address.dart';
import '../../models/customer_details.dart';

enum DeliveryMethod { storePickup, standardDelivery }

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({Key? key}) : super(key: key);

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final CartService _cartService = CartService();
  final ApiService _apiService = ApiService();
  final PaymentService _paymentService = PaymentService();
  final _formKey = GlobalKey<FormState>();
  
  // Form fields
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _streetController = TextEditingController();
  final _apartmentController = TextEditingController();
  final _cityController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _couponController = TextEditingController();
  final _giftMessageController = TextEditingController();
  
  // Read-only flags
  bool _firstNameReadOnly = false;
  bool _lastNameReadOnly = false;
  bool _emailReadOnly = false;
  bool _phoneReadOnly = false;
  bool _streetReadOnly = false;
  bool _apartmentReadOnly = false;
  bool _cityReadOnly = false;
  bool _pincodeReadOnly = false;
  
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
      '10:00 AM - 12:00 PM',
      '12:00 PM - 2:00 PM',
      '2:00 PM - 4:00 PM',
      '4:00 PM - 6:00 PM',
      '6:00 PM - 8:00 PM',
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
    ]
  };

  final List<String> _pickupTimeSlots = [
    '10:00 AM - 11:00 AM',
    '11:00 AM - 12:00 PM',
    '12:00 PM - 1:00 PM',
    '1:00 PM - 2:00 PM',
    '2:00 PM - 3:00 PM',
    '3:00 PM - 4:00 PM',
    '4:00 PM - 5:00 PM',
    '5:00 PM - 6:00 PM',
    '6:00 PM - 7:00 PM',
    '7:00 PM - 8:00 PM',
    '8:00 PM - 9:00 PM',
  ];

  DeliveryMethod _selectedDeliveryMethod = DeliveryMethod.standardDelivery;
  DateTime? _selectedDate;
  String? _selectedTimeSlot;
  bool _isGift = false;
  bool _appliedCoupon = false;
  bool _isLoading = true;
  List<Address> _savedAddresses = [];
  Address? _selectedAddress;
  CustomerDetails? _customerDetails;
  bool _isPointsRedeemed = false;
  final pointsController = TextEditingController();
  static const double POINTS_REDEMPTION_RATE = 1/3; // 3 points = 1 AED
  String? _couponCode;
  double _couponDiscount = 0;

  @override
  void initState() {
    super.initState();
    _loadCustomerDetails();
  }

  double _calculateTotal() {
    double total = _cartService.totalPrice;
    
    // Add delivery charge if applicable
    if (_selectedDeliveryMethod == DeliveryMethod.standardDelivery) {
      total += _deliveryCharge;
    }
    
    // Subtract points value if redeemed
    if (_isPointsRedeemed) {
      total -= _calculatePointsDiscount();
    }
    
    // Subtract coupon discount if applied
    if (_appliedCoupon) {
      total -= _couponDiscount;
    }
    
    return total;
  }

  double _calculatePointsDiscount() {
    if (!_isPointsRedeemed || pointsController.text.isEmpty || _customerDetails == null) return 0;
    int points = int.tryParse(pointsController.text) ?? 0;
    points = points > _customerDetails!.rewardPoints ? _customerDetails!.rewardPoints : points;
    return (points * POINTS_REDEMPTION_RATE);
  }

  Future<void> _loadCustomerDetails() async {
    try {
      final response = await _apiService.sendRequest(
        '/customers/profile',
        method: 'GET',
      );

      if (response.statusCode != 200 || response.data == null) {
        throw Exception('Failed to load customer details');
      }

      final customerData = response.data['data'];
      
      setState(() {
        // Set customer details
        _customerDetails = CustomerDetails(
          id: customerData['id'],
          firstName: customerData['firstName'],
          lastName: customerData['lastName'],
          email: customerData['email'],
          phone: customerData['phone'] ?? '',
          rewardPoints: customerData['rewardPoints'] ?? 0,
        );

        // Set form fields
        _firstNameController.text = customerData['firstName'];
        _lastNameController.text = customerData['lastName'];
        _emailController.text = customerData['email'];
        _phoneController.text = customerData['phone'] ?? '';
        
        // Make fields read-only
        _firstNameReadOnly = true;
        _lastNameReadOnly = true;
        _emailReadOnly = true;
        _phoneReadOnly = true;

        // Set addresses
        _savedAddresses = (customerData['addresses'] as List)
            .map((addr) => Address(
                  id: addr['id'],
                  street: addr['street'],
                  apartment: addr['apartment'] ?? '',
                  emirate: addr['emirate'],
                  city: addr['city'],
                  pincode: addr['pincode'] ?? '',
                  isDefault: addr['isDefault'] ?? false,
                ))
            .toList();

        // Set default address if available
        if (_savedAddresses.isNotEmpty) {
          _selectedAddress = _savedAddresses.firstWhere(
            (addr) => addr.isDefault,
            orElse: () => _savedAddresses.first,
          );
          _updateShippingFields(_selectedAddress!);
        }

        _isLoading = false;
      });
    } catch (e) {
      print('Error loading customer details: $e');
      if (!mounted) return;
      
      setState(() => _isLoading = false);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to load customer details. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final now = DateTime.now();
    final firstDate = now.add(const Duration(days: 1));
    final lastDate = now.add(const Duration(days: 30));

    final picked = await showDatePicker(
      context: context,
      initialDate: firstDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _updateDeliveryCharge() {
    if (_selectedEmirate == null) return;

    setState(() {
      switch (_selectedEmirate) {
        case 'Dubai':
          _deliveryCharge = 10;
          break;
        case 'Abu Dhabi':
        case 'Sharjah':
          _deliveryCharge = 15;
          break;
        default:
          _deliveryCharge = 20;
      }
    });
  }

  Future<void> _applyCoupon() async {
    final code = _couponController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a coupon code')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await _apiService.validateCoupon(code);
      final data = response.data as Map<String, dynamic>;
      
      setState(() {
        _couponCode = code;
        _couponDiscount = (data['discount'] as num).toDouble();
        _appliedCoupon = true;
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Coupon applied successfully!')),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  void _removeCoupon() {
    setState(() {
      _couponCode = null;
      _couponDiscount = 0;
      _appliedCoupon = false;
      _couponController.clear();
    });
  }

  Future<void> _placeOrder() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    
    try {
      // Create order first
      final response = await _apiService.sendRequest(
        '/orders',
        method: 'POST',
        data: _buildOrderData(),
      );

      if (response.statusCode != 200 || response.data == null) {
        throw Exception('Failed to create order');
      }

      final orderId = response.data['data']['id'];

      await _processPayment(orderId);
    } catch (e) {
      print('Error placing order: $e');
      if (!mounted) return;
      
      setState(() => _isLoading = false);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _processPayment(String orderId) async {
    try {
      // Get payment URL from payment service
      final paymentData = await _paymentService.createPaymentOrder(
        orderId: orderId,
      );

      if (!mounted) return;

      // Show payment screen
      final paymentResult = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => PaymentScreen(
            paymentUrl: paymentData['paymentUrl']!,
            orderId: orderId,
            reference: paymentData['reference']!,
            onPaymentComplete: (success) {
              if (success) {
                // Clear cart and show success message
                _cartService.clearCart();
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/orders',
                  (route) => false,
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Payment failed. Please try again.'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
          ),
        ),
      );

      if (paymentResult == false) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment was cancelled. Please try again.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      print('Error processing payment: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to process payment: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Map<String, dynamic> _buildOrderData() {
    return {
      // Customer Information
      'firstName': _firstNameController.text,
      'lastName': _lastNameController.text,
      'email': _emailController.text,
      'phone': _phoneController.text,
      
      // Delivery Information
      'deliveryMethod': _selectedDeliveryMethod == DeliveryMethod.standardDelivery ? 'DELIVERY' : 'PICKUP',
      
      // Date and Time Information
      if (_selectedDeliveryMethod == DeliveryMethod.standardDelivery) ...{
        'deliveryDate': _selectedDate != null 
            ? '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}'
            : null,
        'deliveryTimeSlot': _selectedTimeSlot,
      } else ...{
        'pickupDate': _selectedDate != null 
            ? '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}'
            : null,
        'pickupTimeSlot': _selectedTimeSlot,
      },
      
      // Address Information (only for delivery)
      if (_selectedDeliveryMethod == DeliveryMethod.standardDelivery) ...{
        'streetAddress': _selectedAddress?.street ?? _streetController.text,
        'apartment': _selectedAddress?.apartment ?? _apartmentController.text,
        'emirate': _selectedAddress?.emirate ?? _selectedEmirate,
        'city': _selectedAddress?.city ?? _cityController.text,
        'pincode': _selectedAddress?.pincode ?? _pincodeController.text,
      },
      
      // Order Items
      'items': _cartService.cartItems.map((item) => ({
        'name': item.product.name,
        'variant': item.selectedSize ?? '',
        'price': item.price,
        'quantity': item.quantity,
        'cakeWriting': item.cakeText ?? ''
      })).toList(),
      
      // Payment and Totals
      'paymentMethod': 'CREDIT_CARD', // Changed from 'CARD' to 'CREDIT_CARD'
      'subtotal': _cartService.totalPrice,
      'total': _calculateTotal(),
      
      // Optional Information
      'isGift': _isGift,
      'giftMessage': _isGift ? _giftMessageController.text : '',
      
      // Points & Discounts
      'useRewardPoints': _isPointsRedeemed,
      'pointsToRedeem': _isPointsRedeemed ? int.tryParse(pointsController.text) ?? 0 : 0,
      'couponCode': _appliedCoupon && _couponController.text.isNotEmpty ? _couponController.text.trim() : '',
    };
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _streetController.dispose();
    _apartmentController.dispose();
    _cityController.dispose();
    _pincodeController.dispose();
    _couponController.dispose();
    _giftMessageController.dispose();
    pointsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  _buildContactForm(),
                  const SizedBox(height: 24),
                  _buildDeliveryOptions(),
                  const SizedBox(height: 24),
                  if (_selectedDeliveryMethod == DeliveryMethod.standardDelivery) ...[
                    _buildShippingForm(),
                    const SizedBox(height: 24),
                  ],
                  _buildTimeSlotSelector(),
                  const SizedBox(height: 24),
                  _buildRewardPointsSection(),
                  const SizedBox(height: 24),
                  _buildCouponSection(),
                  const SizedBox(height: 24),
                  _buildOrderItemsSection(),
                  const SizedBox(height: 24),
                  _buildPriceBreakdown(),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _placeOrder,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      'Place Order - ${_cartService.totalPrice.toStringAsFixed(2)} AED',
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                ],
              ),
            ),
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

  Widget _buildContactForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Contact Information'),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                controller: _firstNameController,
                label: 'First Name',
                readOnly: _firstNameReadOnly,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'First name is required';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildTextField(
                controller: _lastNameController,
                label: 'Last Name',
                readOnly: _lastNameReadOnly,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Last name is required';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _emailController,
          label: 'Email',
          readOnly: _emailReadOnly,
          keyboardType: TextInputType.emailAddress,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Email is required';
            }
            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
              return 'Please enter a valid email address';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _phoneController,
          label: 'Phone Number',
          readOnly: _phoneReadOnly,
          keyboardType: TextInputType.phone,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Phone number is required';
            }
            if (!RegExp(r'^[0-9+\-() ]+$').hasMatch(value)) {
              return 'Please enter a valid phone number';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildDeliveryOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Delivery Options'),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildDeliveryMethodCard(
                DeliveryMethod.storePickup,
                'Store Pickup',
                'Pick up from our store',
                Icons.store,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildDeliveryMethodCard(
                DeliveryMethod.standardDelivery,
                'Standard Delivery',
                'Delivery to your address',
                Icons.local_shipping,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    bool readOnly = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
    bool enabled = true,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
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
    final isSelected = _selectedDeliveryMethod == method;

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
            _selectedDeliveryMethod = method;
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
          onChanged: (value) {
            setState(() {
              _selectedEmirate = value;
              _selectedTimeSlot = null; // Reset time slot when emirate changes
              _updateDeliveryCharge();
            });
          },
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

  void _updateShippingFields(Address address) {
    _streetController.text = address.street;
    _apartmentController.text = address.apartment ?? '';
    _cityController.text = address.city;
    _selectedEmirate = address.emirate;
    _pincodeController.text = address.pincode ?? '';
  }

  Widget _buildTimeSlotSelector() {
    List<String> timeSlots = [];
    
    // Only show time slots if a date is selected
    if (_selectedDate != null) {
      if (_selectedDeliveryMethod == DeliveryMethod.storePickup) {
        timeSlots = _pickupTimeSlots;
      } else if (_selectedEmirate != null && _emirateTimeSlots.containsKey(_selectedEmirate)) {
        timeSlots = _emirateTimeSlots[_selectedEmirate]!;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        if (_selectedDeliveryMethod == DeliveryMethod.standardDelivery && _selectedEmirate != null)
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
        // Date Selection
        InkWell(
          onTap: () => _selectDate(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _selectedDate == null
                      ? _selectedDeliveryMethod == DeliveryMethod.storePickup
                          ? 'Select Pickup Date'
                          : 'Select Delivery Date'
                      : getFormattedDate(),
                  style: TextStyle(
                    color: _selectedDate == null ? Colors.grey[600] : Colors.black,
                    fontSize: 16,
                  ),
                ),
                Icon(
                  Icons.calendar_today,
                  color: Colors.grey[600],
                ),
              ],
            ),
          ),
        ),
        if (_selectedDate == null)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 16),
            child: Text(
              'Please select a date',
              style: TextStyle(
                color: Colors.red[700],
                fontSize: 12,
              ),
            ),
          ),
        const SizedBox(height: 16),
        // Time Slot Selection
        DropdownButtonFormField<String>(
          value: _selectedTimeSlot,
          decoration: InputDecoration(
            labelText: _selectedDeliveryMethod == DeliveryMethod.storePickup
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
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          items: timeSlots.map((slot) => DropdownMenuItem(
            value: slot,
            child: Text(slot),
          )).toList(),
          onChanged: timeSlots.isEmpty ? null : (value) {
            setState(() {
              _selectedTimeSlot = value;
            });
          },
          validator: (value) {
            if (_selectedDate == null) {
              return 'Please select a date first';
            }
            if (value == null) {
              return _selectedDeliveryMethod == DeliveryMethod.storePickup
                  ? 'Please select a pickup time'
                  : 'Please select a delivery time';
            }
            return null;
          },
        ),
      ],
    );
  }

  String getFormattedDate() {
    if (_selectedDate == null) return '';
    return '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}';
  }

  Widget _buildRewardPointsSection() {
    if (_customerDetails == null || _customerDetails!.rewardPoints <= 0) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Reward Points',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${_customerDetails?.rewardPoints ?? 0} points available',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Redeem your points (3 points = 1 AED)',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: pointsController,
                  keyboardType: TextInputType.number,
                  enabled: _isPointsRedeemed,
                  decoration: InputDecoration(
                    hintText: 'Enter points to redeem',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  onChanged: (value) {
                    int? points = int.tryParse(value);
                    if (points != null && _customerDetails != null) {
                      if (points > _customerDetails!.rewardPoints) {
                        pointsController.text = _customerDetails!.rewardPoints.toString();
                      }
                      setState(() {});
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Switch(
                value: _isPointsRedeemed,
                onChanged: (value) {
                  setState(() {
                    _isPointsRedeemed = value;
                    if (!value) {
                      pointsController.clear();
                    }
                  });
                },
                activeColor: Colors.green,
              ),
            ],
          ),
          if (_isPointsRedeemed && pointsController.text.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'You will save ${_calculatePointsDiscount().toStringAsFixed(2)} AED',
              style: const TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

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
                    onFieldSubmitted: (value) => _applyCoupon(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _applyCoupon,
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
            _buildPriceRow('Subtotal', _cartService.totalPrice),
            if (_selectedDeliveryMethod == DeliveryMethod.standardDelivery)
              _buildPriceRow('Delivery Charge', _deliveryCharge),
            if (_isPointsRedeemed)
              _buildPriceRow(
                'Points Redeemed (${pointsController.text} points)',
                -_calculatePointsDiscount(),
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

  Widget _buildOrderItemsSection() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Order Items',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _cartService.cartItems.length,
            itemBuilder: (context, index) {
              final item = _cartService.cartItems[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product Image
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.grey[100],
                      ),
                      child: item.product.imageUrl != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                item.product.imageUrl!,
                                fit: BoxFit.cover,
                              ),
                            )
                          : const Icon(Icons.cake, size: 30, color: Colors.grey),
                    ),
                    const SizedBox(width: 12),
                    // Product Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.product.name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (item.selectedSize != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Size: ${item.selectedSize}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                          if (item.cakeText != null && item.cakeText!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Text: ${item.cakeText}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Price and Quantity
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${item.price.toStringAsFixed(0)} AED',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Qty: ${item.quantity}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
