import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/address.dart';
import '../../services/api_service.dart';
import '../../utils/toast_utils.dart';
import '../../widgets/custom_text_field.dart';

class EditAddressScreen extends StatefulWidget {
  final Address? address;

  const EditAddressScreen({super.key, this.address});

  @override
  State<EditAddressScreen> createState() => _EditAddressScreenState();
}

class _EditAddressScreenState extends State<EditAddressScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _streetController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _postalCodeController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isLoading = false;
  bool _isDefault = false;

  @override
  void initState() {
    super.initState();
    if (widget.address != null) {
      _nameController.text = widget.address!.name;
      _streetController.text = widget.address!.street;
      _cityController.text = widget.address!.city;
      _stateController.text = widget.address!.state;
      _postalCodeController.text = widget.address!.postalCode;
      // Remove +971 prefix if it exists
      _phoneController.text = widget.address!.phoneNumber.replaceFirst('+971', '');
      _isDefault = widget.address!.isDefault;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _streetController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _postalCodeController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _saveAddress() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      // Add +971 prefix to phone number if not already present
      String phoneNumber = _phoneController.text.trim();
      if (!phoneNumber.startsWith('+971')) {
        phoneNumber = '+971$phoneNumber';
      }

      final address = Address(
        id: widget.address?.id,
        name: _nameController.text,
        street: _streetController.text,
        city: _cityController.text,
        state: _stateController.text,
        postalCode: _postalCodeController.text,
        phoneNumber: phoneNumber,
        isDefault: _isDefault,
      );

      if (widget.address == null) {
        await ApiService().addAddress(address);
        ToastUtils.showSuccessToast('Address added successfully');
      } else {
        await ApiService().updateAddress(widget.address!.id!, address);
        ToastUtils.showSuccessToast('Address updated successfully');
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      ToastUtils.showErrorToast(
          'Failed to ${widget.address == null ? 'add' : 'update'} address: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.address == null ? 'Add' : 'Edit'} Address'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CustomTextField(
                      controller: _nameController,
                      labelText: 'Address Name',
                      hintText: 'e.g., Home, Office',
                      validator: (value) {
                        if (value?.isEmpty ?? true) {
                          return 'Please enter an address name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _streetController,
                      labelText: 'Street Address',
                      validator: (value) {
                        if (value?.isEmpty ?? true) {
                          return 'Please enter a street address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _cityController,
                      labelText: 'City',
                      validator: (value) {
                        if (value?.isEmpty ?? true) {
                          return 'Please enter a city';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _stateController,
                      labelText: 'Emirate',
                      validator: (value) {
                        if (value?.isEmpty ?? true) {
                          return 'Please enter an emirate';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _postalCodeController,
                      labelText: 'Postal Code',
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      validator: (value) {
                        if (value?.isEmpty ?? true) {
                          return 'Please enter a postal code';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _phoneController,
                      labelText: 'Phone Number',
                      hintText: '55 555 5555',
                      keyboardType: TextInputType.phone,
                      prefixIcon: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '+971',
                              style: TextStyle(
                                color: Theme.of(context).primaryColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              height: 24,
                              width: 1,
                              color: Colors.grey[300],
                            ),
                          ],
                        ),
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(9),
                      ],
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a phone number';
                        }
                        if (value.length < 9) {
                          return 'Please enter a valid UAE phone number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    CheckboxListTile(
                      value: _isDefault,
                      onChanged: (value) {
                        setState(() => _isDefault = value ?? false);
                      },
                      title: const Text('Set as default address'),
                      subtitle: const Text(
                          'This address will be selected by default when placing orders'),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      tileColor: Colors.grey[100],
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _saveAddress,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                          '${widget.address == null ? 'Add' : 'Update'} Address'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
