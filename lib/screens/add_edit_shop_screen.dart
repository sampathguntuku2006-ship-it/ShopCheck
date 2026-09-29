import 'package:flutter/material.dart';
import '../models/shop.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/location_service.dart';

class AddEditShopScreen extends StatefulWidget {
  final Shop? existingShop;

  const AddEditShopScreen({super.key, this.existingShop});

  @override
  State<AddEditShopScreen> createState() => _AddEditShopScreenState();
}

class _AddEditShopScreenState extends State<AddEditShopScreen> {
  final _formKey = GlobalKey<FormState>();
  final DatabaseService _databaseService = DatabaseService();
  final AuthService _authService = AuthService();

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _cityController;
  late TextEditingController _stateController;
  late TextEditingController _pincodeController;
  late TextEditingController _descriptionController;
  late TextEditingController _tempClosedReasonController;

  String _selectedCategory = 'Grocery & Supermarket';
  double _latitude = LocationService.defaultIndiaLat;
  double _longitude = LocationService.defaultIndiaLng;
  double _mapCenterLat = LocationService.defaultIndiaLat;
  double _mapCenterLng = LocationService.defaultIndiaLng;
  double _mapZoomLevel = 2.4;
  bool _isTemporarilyClosed = false;
  bool _isSaving = false;
  bool _isLocating = false;

  final Map<int, DaySchedule> _schedule = {};

  final List<String> _categories = [
    'Grocery & Supermarket',
    'Pharmacy & Wellness',
    'Bakery & Pastries',
    'Coffee & Cafe',
    'Electronics & Repairs',
    'Restaurant & Dining',
    'Books & Stationery',
    'Flowers & Gifts',
    'Clothing & Fashion',
    'Hardware & Tools',
  ];

  @override
  void initState() {
    super.initState();
    final s = widget.existingShop;
    _nameController = TextEditingController(text: s?.name ?? '');
    _phoneController = TextEditingController(text: s?.phone ?? '');
    _addressController = TextEditingController(text: s?.address ?? '');
    _cityController = TextEditingController(text: s?.city ?? 'Hyderabad');
    _stateController = TextEditingController(text: s?.state ?? 'Telangana');
    _pincodeController = TextEditingController(text: s?.pincode ?? '500001');
    _descriptionController = TextEditingController(text: s?.description ?? '');
    _tempClosedReasonController = TextEditingController(text: s?.temporaryClosureReason ?? '');

    if (s != null) {
      _selectedCategory = s.category;
      _latitude = s.latitude;
      _longitude = s.longitude;
      _mapCenterLat = s.latitude;
      _mapCenterLng = s.longitude;
      _mapZoomLevel = 3.0;
      _isTemporarilyClosed = s.isTemporarilyClosed;
      _schedule.addAll(s.weeklySchedule);
    } else {
      _mapCenterLat = _latitude;
      _mapCenterLng = _longitude;
      // Initialize default daily schedule: 9:00 AM - 9:00 PM for all 7 days
      for (int i = 1; i <= 7; i++) {
        _schedule[i] = const DaySchedule(
          isOpen: true,
          openHour: 9,
          openMinute: 0,
          closeHour: 21,
          closeMinute: 0,
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    _descriptionController.dispose();
    _tempClosedReasonController.dispose();
    super.dispose();
  }

  IconData _iconForCategory(String cat) {
    if (cat.contains('Grocery')) return Icons.shopping_basket_rounded;
    if (cat.contains('Pharmacy')) return Icons.local_pharmacy_rounded;
    if (cat.contains('Bakery')) return Icons.bakery_dining_rounded;
    if (cat.contains('Coffee')) return Icons.coffee_rounded;
    if (cat.contains('Electronics')) return Icons.devices_rounded;
    if (cat.contains('Restaurant')) return Icons.restaurant_rounded;
    if (cat.contains('Books')) return Icons.menu_book_rounded;
    if (cat.contains('Flowers')) return Icons.local_florist_rounded;
    if (cat.contains('Clothing')) return Icons.checkroom_rounded;
    return Icons.storefront_rounded;
  }

  Future<void> _pickLocationOnMap() async {
    final result = await showModalBottomSheet<({double lat, double lng, String city, String state})>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return _MapLocationPickerSheet(
          initialLat: _latitude,
          initialLng: _longitude,
          initialCity: _cityController.text,
        );
      },
    );

    if (result != null) {
      setState(() {
        _latitude = result.lat;
        _longitude = result.lng;
        _mapCenterLat = result.lat;
        _mapCenterLng = result.lng;
        _mapZoomLevel = 3.0;
        if (result.city.isNotEmpty) _cityController.text = result.city;
        if (result.state.isNotEmpty) _stateController.text = result.state;
      });
    }
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _isLocating = true);
    try {
      final res = await LocationService().requestLocationDetailed(requestIfNotGranted: true);
      if (!mounted) return;
      if (res.position != null) {
        final newLat = double.parse(res.position!.latitude.toStringAsFixed(4));
        final newLng = double.parse(res.position!.longitude.toStringAsFixed(4));
        setState(() {
          _latitude = newLat;
          _longitude = newLng;
          _mapCenterLat = newLat;
          _mapCenterLng = newLng;
          _mapZoomLevel = 3.2;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Location detected: ${_latitude.toStringAsFixed(4)}, ${_longitude.toStringAsFixed(4)}',
            ),
            backgroundColor: const Color(0xFF16A34A),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.message),
            backgroundColor: const Color(0xFFE11D48),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not acquire GPS location: $e'),
          backgroundColor: const Color(0xFFE11D48),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLocating = false);
      }
    }
  }

  void _confirmLocation() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Location confirmed: ${_latitude.toStringAsFixed(4)}° N, ${_longitude.toStringAsFixed(4)}° E',
        ),
        backgroundColor: const Color(0xFF16A34A),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _handleEmbeddedMapTap(Offset localPos, Size size) {
    final scale = (size.width / 35.0) * _mapZoomLevel;
    final lngDelta = (localPos.dx - (size.width / 2.0)) / scale;
    final latDelta = ((size.height / 2.0) - localPos.dy) / (scale * 1.1);
    final lat = (_mapCenterLat + latDelta).clamp(8.0, 36.0);
    final lng = (_mapCenterLng + lngDelta).clamp(68.0, 97.0);
    setState(() {
      _latitude = double.parse(lat.toStringAsFixed(4));
      _longitude = double.parse(lng.toStringAsFixed(4));
    });
  }

  void _handleEmbeddedMapPan(DragUpdateDetails details, Size size) {
    final scale = (size.width / 35.0) * _mapZoomLevel;
    final lngShift = -details.delta.dx / scale;
    final latShift = details.delta.dy / (scale * 1.1);
    setState(() {
      _mapCenterLat = (_mapCenterLat + latShift).clamp(8.0, 36.0);
      _mapCenterLng = (_mapCenterLng + lngShift).clamp(68.0, 97.0);
    });
  }

  Future<void> _editDayTime(int dayInt, bool isOpening) async {
    final current = _schedule[dayInt] ?? const DaySchedule();
    final initialTime = TimeOfDay(
      hour: isOpening ? current.openHour : current.closeHour,
      minute: isOpening ? current.openMinute : current.closeMinute,
    );

    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (picked != null) {
      setState(() {
        _schedule[dayInt] = DaySchedule(
          isOpen: current.isOpen,
          is24Hours: false,
          openHour: isOpening ? picked.hour : current.openHour,
          openMinute: isOpening ? picked.minute : current.openMinute,
          closeHour: !isOpening ? picked.hour : current.closeHour,
          closeMinute: !isOpening ? picked.minute : current.closeMinute,
        );
      });
    }
  }

  Future<void> _handleSaveShop() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final ownerPhone = _authService.currentUser?.phone ?? 'system_admin';
    final shopToSave = Shop(
      id: widget.existingShop?.id ?? 'shop_${DateTime.now().millisecondsSinceEpoch}',
      ownerId: widget.existingShop?.ownerId ?? ownerPhone,
      name: _nameController.text.trim(),
      category: _selectedCategory,
      categoryIcon: _iconForCategory(_selectedCategory),
      address: _addressController.text.trim(),
      city: _cityController.text.trim(),
      state: _stateController.text.trim(),
      pincode: _pincodeController.text.trim(),
      latitude: _latitude,
      longitude: _longitude,
      phone: _phoneController.text.trim(),
      distance: widget.existingShop?.distance ?? '1.0 km',
      description: _descriptionController.text.trim(),
      isTemporarilyClosed: _isTemporarilyClosed,
      temporaryClosureReason: _isTemporarilyClosed ? _tempClosedReasonController.text.trim() : null,
      weeklySchedule: _schedule,
    );

    final success = await _databaseService.saveShop(shopToSave, ownerPhone);

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.existingShop != null
                ? 'Shop details updated successfully!'
                : 'Shop registered successfully! Visible to customers.',
          ),
          backgroundColor: const Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You do not have permission to edit this shop.'),
          backgroundColor: Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingShop != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          isEditing ? 'Edit Shop' : 'Add Shop',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Basic Information Section
              _buildSectionCard(
                title: 'Shop Information',
                icon: Icons.storefront_rounded,
                children: [
                  _buildTextField(
                    controller: _nameController,
                    label: 'Shop Name',
                    hint: 'e.g. Sri Balaji Supermarket',
                    validator: (v) => v == null || v.trim().isEmpty ? 'Enter shop name' : null,
                  ),
                  const SizedBox(height: 14),

                  // Category Dropdown
                  const Text(
                    'Shop Category',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedCategory,
                    items: _categories
                        .map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 14))))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedCategory = val);
                    },
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 14),

                  _buildTextField(
                    controller: _phoneController,
                    label: 'Phone Number',
                    hint: 'e.g. +91 98765 43210',
                    keyboardType: TextInputType.phone,
                    validator: (v) => v == null || v.trim().isEmpty ? 'Enter phone number' : null,
                  ),
                  const SizedBox(height: 14),

                  _buildTextField(
                    controller: _descriptionController,
                    label: 'Shop Description',
                    hint: 'Brief description of products and services offered',
                    maxLines: 3,
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Location Section
              _buildSectionCard(
                title: 'Shop Location',
                icon: Icons.location_on_rounded,
                children: [
                  _buildTextField(
                    controller: _addressController,
                    label: 'Street Address',
                    hint: 'e.g. Shop 4, Ground Floor, Banjara Hills Road 12',
                    validator: (v) => v == null || v.trim().isEmpty ? 'Enter street address' : null,
                  ),
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _cityController,
                          label: 'City',
                          hint: 'e.g. Hyderabad',
                          validator: (v) => v == null || v.trim().isEmpty ? 'Enter city' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          controller: _stateController,
                          label: 'State',
                          hint: 'e.g. Telangana',
                          validator: (v) => v == null || v.trim().isEmpty ? 'Enter state' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  _buildTextField(
                    controller: _pincodeController,
                    label: 'PIN Code',
                    hint: 'e.g. 500034',
                    keyboardType: TextInputType.number,
                    validator: (v) => v == null || v.trim().isEmpty ? 'Enter PIN code' : null,
                  ),
                  const SizedBox(height: 16),

                  // Selected Coordinates & Location Action Buttons
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF16A34A),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.pin_drop_rounded, color: Colors.white, size: 16),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'Exact Shop Coordinates',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFF86EFAC)),
                              ),
                              child: const Text(
                                'GPS Pinned',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF15803D)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Embedded Interactive Google Map View
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            height: 200,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
                            ),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final size = Size(constraints.maxWidth, constraints.maxHeight);
                                return Stack(
                                  children: [
                                    Positioned.fill(
                                      child: GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTapUp: (details) => _handleEmbeddedMapTap(details.localPosition, size),
                                        onPanUpdate: (details) => _handleEmbeddedMapPan(details, size),
                                        child: CustomPaint(
                                          size: size,
                                          painter: _LocationPickerMapPainter(
                                            centerLat: _mapCenterLat,
                                            centerLng: _mapCenterLng,
                                            zoomLevel: _mapZoomLevel,
                                            pinLat: _latitude,
                                            pinLng: _longitude,
                                          ),
                                        ),
                                      ),
                                    ),
                                    // Top Map Info Badge
                                    Positioned(
                                      top: 8,
                                      left: 8,
                                      right: 8,
                                      child: IgnorePointer(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.90),
                                            borderRadius: BorderRadius.circular(16),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(alpha: 0.08),
                                                blurRadius: 4,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: const Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.touch_app_rounded, size: 12, color: Color(0xFF16A34A)),
                                              SizedBox(width: 4),
                                              Flexible(
                                                child: Text(
                                                  'Tap map to set pin • Drag to pan',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w700,
                                                    color: Color(0xFF334155),
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    // Floating Map Controls
                                    Positioned(
                                      right: 8,
                                      bottom: 8,
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          _buildMiniMapButton(
                                            icon: Icons.add_rounded,
                                            tooltip: 'Zoom In',
                                            onTap: () => setState(() => _mapZoomLevel = (_mapZoomLevel + 0.5).clamp(0.8, 6.0)),
                                          ),
                                          const SizedBox(height: 4),
                                          _buildMiniMapButton(
                                            icon: Icons.remove_rounded,
                                            tooltip: 'Zoom Out',
                                            onTap: () => setState(() => _mapZoomLevel = (_mapZoomLevel - 0.5).clamp(0.8, 6.0)),
                                          ),
                                          const SizedBox(height: 4),
                                          _buildMiniMapButton(
                                            icon: Icons.center_focus_strong_rounded,
                                            tooltip: 'Center on Pin',
                                            onTap: () => setState(() {
                                              _mapCenterLat = _latitude;
                                              _mapCenterLng = _longitude;
                                            }),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('LATITUDE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${_latitude.toStringAsFixed(4)}° N',
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('LONGITUDE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${_longitude.toStringAsFixed(4)}° E',
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: OutlinedButton.icon(
                            onPressed: _isLocating ? null : _useCurrentLocation,
                            icon: _isLocating
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF16A34A)),
                                  )
                                : const Icon(Icons.my_location_rounded, size: 18),
                            label: Text(
                              _isLocating ? 'Detecting GPS Location...' : 'Use My Current Location',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF16A34A),
                              side: const BorderSide(color: Color(0xFF16A34A), width: 1.5),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              backgroundColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 44,
                                child: ElevatedButton.icon(
                                  onPressed: _confirmLocation,
                                  icon: const Icon(Icons.check_circle_rounded, size: 18),
                                  label: const Text(
                                    'Confirm Location',
                                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF16A34A),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: SizedBox(
                                height: 44,
                                child: OutlinedButton.icon(
                                  onPressed: _pickLocationOnMap,
                                  icon: const Icon(Icons.fullscreen_rounded, size: 18),
                                  label: const Text(
                                    'Select Exact Location on Map',
                                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF0F172A),
                                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    backgroundColor: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Weekly Operating Hours Section
              _buildSectionCard(
                title: 'Weekly Opening Hours',
                icon: Icons.schedule_rounded,
                children: [
                  const Text(
                    'Configure different opening and closing times for each day of the week.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 14),

                  ...List.generate(7, (idx) {
                    final dayInt = idx + 1;
                    final schedule = _schedule[dayInt] ?? const DaySchedule();

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: schedule.isOpen ? const Color(0xFFF8FAFC) : const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: schedule.isOpen ? const Color(0xFFE2E8F0) : const Color(0xFFFCA5A5),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Text(
                                Shop.getWeekdayName(dayInt),
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                              ),
                              const Spacer(),
                              Text(
                                schedule.isOpen ? 'Open' : 'Closed for day',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: schedule.isOpen ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Switch(
                                value: schedule.isOpen,
                                activeThumbColor: const Color(0xFF16A34A),
                                onChanged: (val) {
                                  setState(() {
                                    _schedule[dayInt] = DaySchedule(
                                      isOpen: val,
                                      is24Hours: schedule.is24Hours,
                                      openHour: schedule.openHour,
                                      openMinute: schedule.openMinute,
                                      closeHour: schedule.closeHour,
                                      closeMinute: schedule.closeMinute,
                                    );
                                  });
                                },
                              ),
                            ],
                          ),
                          if (schedule.isOpen) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => _editDayTime(dayInt, true),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    child: Text(
                                      'Opens: ${DaySchedule.formatTime(schedule.openHour, schedule.openMinute)}',
                                      style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => _editDayTime(dayInt, false),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    child: Text(
                                      'Closes: ${DaySchedule.formatTime(schedule.closeHour, schedule.closeMinute)}',
                                      style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
                ],
              ),
              const SizedBox(height: 18),

              // Temporary Closure Section
              _buildSectionCard(
                title: 'Temporary Closure',
                icon: Icons.pause_circle_outline_rounded,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Mark as Temporarily Closed', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    subtitle: const Text('Show "TEMPORARILY CLOSED" in amber to customers without deleting schedule.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    value: _isTemporarilyClosed,
                    activeThumbColor: const Color(0xFFD97706),
                    onChanged: (val) => setState(() => _isTemporarilyClosed = val),
                  ),
                  if (_isTemporarilyClosed) ...[
                    const SizedBox(height: 10),
                    _buildTextField(
                      controller: _tempClosedReasonController,
                      label: 'Closure Reason',
                      hint: 'e.g. Renovation, Deep cleaning, Emergency holiday',
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 24),

              // Save Shop Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _handleSaveShop,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                        )
                      : Text(
                          isEditing ? 'Save Changes' : 'Save Shop',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniMapButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(icon, size: 16, color: const Color(0xFF0F172A)),
        tooltip: tooltip,
        onPressed: onTap,
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: const Color(0xFF0F172A)),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    ),
  );
}

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF16A34A), width: 1.5)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }
}

/// Interactive modal sheet allowing the shop owner to select the exact shop location
/// directly on an interactive map, view latitude and longitude in real time, and confirm.
class _MapLocationPickerSheet extends StatefulWidget {
  final double initialLat;
  final double initialLng;
  final String initialCity;

  const _MapLocationPickerSheet({
    required this.initialLat,
    required this.initialLng,
    required this.initialCity,
  });

  @override
  State<_MapLocationPickerSheet> createState() => _MapLocationPickerSheetState();
}

class _MapLocationPickerSheetState extends State<_MapLocationPickerSheet> {
  late double _pickedLat;
  late double _pickedLng;
  late String _pickedCity;
  late String _pickedState;

  late double _centerLat;
  late double _centerLng;
  double _zoomLevel = 2.4;

  final Map<String, ({double lat, double lng, String state})> _presetMap = {
    'India Center': (lat: LocationService.defaultIndiaLat, lng: LocationService.defaultIndiaLng, state: 'Central India'),
    ...LocationService.indianCities,
  };

  @override
  void initState() {
    super.initState();
    _pickedLat = widget.initialLat;
    _pickedLng = widget.initialLng;
    _pickedCity = widget.initialCity.isNotEmpty ? widget.initialCity : 'Hyderabad';
    _pickedState = 'Telangana';

    _centerLat = _pickedLat;
    _centerLng = _pickedLng;

    // If initial position is national default, start at country zoom
    if ((_pickedLat - LocationService.defaultIndiaLat).abs() < 0.1 &&
        (_pickedLng - LocationService.defaultIndiaLng).abs() < 0.1) {
      _zoomLevel = 1.0;
    }
  }

  void _selectPreset(String city, ({double lat, double lng, String state}) data) {
    setState(() {
      _pickedCity = city;
      _pickedState = data.state;
      _pickedLat = data.lat;
      _pickedLng = data.lng;
      _centerLat = data.lat;
      _centerLng = data.lng;
      _zoomLevel = (city == 'India Center') ? 1.0 : 2.8;
    });
  }

  ({double lat, double lng}) _fromScreen(Offset pos, Size size) {
    final scale = (size.width / 35.0) * _zoomLevel;
    final lngDelta = (pos.dx - (size.width / 2.0)) / scale;
    final latDelta = ((size.height / 2.0) - pos.dy) / (scale * 1.1);
    final lat = (_centerLat + latDelta).clamp(8.0, 36.0);
    final lng = (_centerLng + lngDelta).clamp(68.0, 97.0);
    return (
      lat: double.parse(lat.toStringAsFixed(4)),
      lng: double.parse(lng.toStringAsFixed(4)),
    );
  }

  void _handleMapTap(Offset localPos, Size size) {
    final coords = _fromScreen(localPos, size);
    setState(() {
      _pickedLat = coords.lat;
      _pickedLng = coords.lng;
    });
  }

  void _handlePanUpdate(DragUpdateDetails details, Size size) {
    final scale = (size.width / 35.0) * _zoomLevel;
    final lngShift = -details.delta.dx / scale;
    final latShift = details.delta.dy / (scale * 1.1);
    setState(() {
      _centerLat = (_centerLat + latShift).clamp(8.0, 36.0);
      _centerLng = (_centerLng + lngShift).clamp(68.0, 97.0);
    });
  }

  void _zoomIn() {
    setState(() {
      _zoomLevel = (_zoomLevel + 0.6).clamp(0.8, 6.0);
    });
  }

  void _zoomOut() {
    setState(() {
      _zoomLevel = (_zoomLevel - 0.6).clamp(0.8, 6.0);
    });
  }

  void _recenterOnPin() {
    setState(() {
      _centerLat = _pickedLat;
      _centerLng = _pickedLng;
    });
  }

  bool _isLocating = false;

  Future<void> _useCurrentLocation() async {
    setState(() => _isLocating = true);
    try {
      final res = await LocationService().requestLocationDetailed(requestIfNotGranted: true);
      if (!mounted) return;
      if (res.position != null) {
        final newLat = double.parse(res.position!.latitude.toStringAsFixed(4));
        final newLng = double.parse(res.position!.longitude.toStringAsFixed(4));
        setState(() {
          _pickedLat = newLat;
          _pickedLng = newLng;
          _centerLat = newLat;
          _centerLng = newLng;
          _zoomLevel = 3.2;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Current location detected: ${_pickedLat.toStringAsFixed(4)}, ${_pickedLng.toStringAsFixed(4)}',
            ),
            backgroundColor: const Color(0xFF16A34A),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.message),
            backgroundColor: const Color(0xFFE11D48),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not acquire GPS location: $e'),
          backgroundColor: const Color(0xFFE11D48),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLocating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.90;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sheet Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16A34A),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.pin_drop_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Select Shop Location',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                      ),
                      const Text(
                        'Tap anywhere on the map to place the shop pin',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Use My Current Location Action Button
            SizedBox(
              width: double.infinity,
              height: 40,
              child: OutlinedButton.icon(
                onPressed: _isLocating ? null : _useCurrentLocation,
                icon: _isLocating
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF16A34A)),
                      )
                    : const Icon(Icons.my_location_rounded, size: 16, color: Color(0xFF16A34A)),
                label: Text(
                  _isLocating ? 'Detecting Location...' : 'Use My Current Location',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF16A34A),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF16A34A), width: 1.2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  backgroundColor: const Color(0xFFF0FDF4),
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Indian City Presets Row
            const Text(
              'Quick Jump Presets:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _presetMap.entries.map((entry) {
                  final isSel = _pickedCity.toLowerCase() == entry.key.toLowerCase();
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(entry.key),
                      selected: isSel,
                      onSelected: (_) => _selectPreset(entry.key, entry.value),
                      selectedColor: const Color(0xFF16A34A),
                      labelStyle: TextStyle(
                        color: isSel ? Colors.white : const Color(0xFF1E293B),
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      showCheckmark: false,
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),

            // Interactive Map Box
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final size = Size(constraints.maxWidth, constraints.maxHeight);

                      return Stack(
                        children: [
                          // Interactive Map Canvas
                          Positioned.fill(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTapUp: (details) => _handleMapTap(details.localPosition, size),
                              onPanUpdate: (details) => _handlePanUpdate(details, size),
                              child: CustomPaint(
                                size: size,
                                painter: _LocationPickerMapPainter(
                                  centerLat: _centerLat,
                                  centerLng: _centerLng,
                                  zoomLevel: _zoomLevel,
                                  pinLat: _pickedLat,
                                  pinLng: _pickedLng,
                                ),
                              ),
                            ),
                          ),

                          // Top Info Pill
                          Positioned(
                            top: 10,
                            left: 10,
                            right: 10,
                            child: IgnorePointer(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.92),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.08),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.touch_app_rounded, size: 14, color: Color(0xFF16A34A)),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        'Tap to pin • Drag to pan • Zoom: ${_zoomLevel.toStringAsFixed(1)}x',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF334155),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // Floating Map Controls (+ / - / Recenter)
                          Positioned(
                            right: 12,
                            bottom: 12,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildMapControlButton(
                                  icon: Icons.add_rounded,
                                  tooltip: 'Zoom In',
                                  onTap: _zoomIn,
                                ),
                                const SizedBox(height: 6),
                                _buildMapControlButton(
                                  icon: Icons.remove_rounded,
                                  tooltip: 'Zoom Out',
                                  onTap: _zoomOut,
                                ),
                                const SizedBox(height: 6),
                                _buildMapControlButton(
                                  icon: Icons.my_location_rounded,
                                  tooltip: 'Use GPS Location',
                                  onTap: _useCurrentLocation,
                                ),
                                const SizedBox(height: 6),
                                _buildMapControlButton(
                                  icon: Icons.center_focus_strong_rounded,
                                  tooltip: 'Center on Pin',
                                  onTap: _recenterOnPin,
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Real-time Coordinates Display Card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'SELECTED SHOP COORDINATES',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Latitude: ${_pickedLat.toStringAsFixed(4)}° N, Longitude: ${_pickedLng.toStringAsFixed(4)}° E',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Text(
                      _pickedCity,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF15803D)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Confirm Location Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context, (
                    lat: _pickedLat,
                    lng: _pickedLng,
                    city: _pickedCity,
                    state: _pickedState,
                  ));
                },
                icon: const Icon(Icons.check_circle_rounded, size: 20),
                label: const Text(
                  'Confirm Location',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapControlButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, size: 20, color: const Color(0xFF0F172A)),
        tooltip: tooltip,
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
        onPressed: onTap,
      ),
    );
  }
}

/// Custom map painter rendering India subcontinent boundaries, regional city anchors,
/// and the active shop location marker pin.
class _LocationPickerMapPainter extends CustomPainter {
  final double centerLat;
  final double centerLng;
  final double zoomLevel;
  final double pinLat;
  final double pinLng;

  _LocationPickerMapPainter({
    required this.centerLat,
    required this.centerLng,
    required this.zoomLevel,
    required this.pinLat,
    required this.pinLng,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Map Canvas Background
    final bgPaint = Paint()..color = const Color(0xFFE2E8F0);
    canvas.drawRect(Offset.zero & size, bgPaint);

    // Subtle Map Grid
    final gridPaint = Paint()
      ..color = const Color(0xFFCBD5E1).withValues(alpha: 0.5)
      ..strokeWidth = 1.0;
    const gridSize = 35.0;
    for (double x = 0; x < size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // India Subcontinent Landmass Polygon
    final landPaint = Paint()..color = const Color(0xFFF8FAFC);
    final borderPaint = Paint()
      ..color = const Color(0xFF94A3B8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final indiaCoords = [
      (lat: 35.5, lng: 74.5), // North Kashmir
      (lat: 32.5, lng: 78.5), // Ladakh
      (lat: 28.5, lng: 80.5), // Uttarakhand
      (lat: 27.0, lng: 88.5), // Sikkim
      (lat: 28.0, lng: 96.0), // Arunachal
      (lat: 24.5, lng: 93.5), // Manipur
      (lat: 22.0, lng: 89.0), // Bengal delta
      (lat: 19.5, lng: 85.5), // Odisha
      (lat: 13.0, lng: 80.3), // Chennai
      (lat: 8.1, lng: 77.5),  // Kanyakumari
      (lat: 15.0, lng: 73.8), // Goa
      (lat: 19.0, lng: 72.8), // Mumbai
      (lat: 23.0, lng: 68.5), // Gujarat
      (lat: 27.5, lng: 71.0), // Rajasthan
      (lat: 31.5, lng: 74.8), // Punjab
    ];

    final path = Path();
    bool first = true;
    for (final c in indiaCoords) {
      final pt = _toScreen(c.lat, c.lng, size);
      if (first) {
        path.moveTo(pt.dx, pt.dy);
        first = false;
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    path.close();
    canvas.drawPath(path, landPaint);
    canvas.drawPath(path, borderPaint);

    // Major Indian City Anchors
    final cityDotPaint = Paint()..color = const Color(0xFF94A3B8);
    for (final entry in LocationService.indianCities.entries) {
      final pt = _toScreen(entry.value.lat, entry.value.lng, size);
      if (pt.dx >= -10 && pt.dx <= size.width + 10 && pt.dy >= -10 && pt.dy <= size.height + 10) {
        canvas.drawCircle(pt, 3.5, cityDotPaint);
      }
    }

    // Active Shop Location Marker Pin
    final pinPt = _toScreen(pinLat, pinLng, size);

    // Pulse Circle around Pin
    final pulsePaint = Paint()
      ..color = const Color(0xFF16A34A).withValues(alpha: 0.22);
    canvas.drawCircle(pinPt, 22, pulsePaint);

    // Pin Drop Shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(pinPt.dx, pinPt.dy + 3), width: 14, height: 6),
      shadowPaint,
    );

    // Pin Body
    final pinPaint = Paint()..color = const Color(0xFF16A34A);
    canvas.drawCircle(Offset(pinPt.dx, pinPt.dy - 16), 11, pinPaint);
    final innerDot = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(pinPt.dx, pinPt.dy - 16), 5, innerDot);

    // Pin Triangle Tip pointing to exact coordinate
    final pinPath = Path()
      ..moveTo(pinPt.dx - 7, pinPt.dy - 9)
      ..lineTo(pinPt.dx + 7, pinPt.dy - 9)
      ..lineTo(pinPt.dx, pinPt.dy)
      ..close();
    canvas.drawPath(pinPath, pinPaint);
  }

  Offset _toScreen(double lat, double lng, Size size) {
    final latDelta = (lat - centerLat);
    final lngDelta = (lng - centerLng);
    final scale = (size.width / 35.0) * zoomLevel;
    final screenX = (size.width / 2.0) + (lngDelta * scale);
    final screenY = (size.height / 2.0) - (latDelta * scale * 1.1);
    return Offset(screenX, screenY);
  }

  @override
  bool shouldRepaint(covariant _LocationPickerMapPainter oldDelegate) {
    return oldDelegate.centerLat != centerLat ||
        oldDelegate.centerLng != centerLng ||
        oldDelegate.zoomLevel != zoomLevel ||
        oldDelegate.pinLat != pinLat ||
        oldDelegate.pinLng != pinLng;
  }
}
