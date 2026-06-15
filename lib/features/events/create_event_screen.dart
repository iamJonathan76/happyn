import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CreateEventScreen extends StatefulWidget {
  const CreateEventScreen({super.key});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _cityController = TextEditingController();
  final _imageUrlController = TextEditingController();
  final _priceController = TextEditingController();

  String _selectedCategory = 'Music';
  DateTime _startDate = DateTime.now().add(const Duration(days: 1));
  DateTime _endDate = DateTime.now().add(const Duration(days: 1, hours: 3));
  bool _isLoading = false;

  final _categories = [
    'Music', 'Party', 'Festival', 'Networking',
    'Art', 'Sports', 'Food & Drink', 'Other'
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _cityController.dispose();
    _imageUrlController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF7C3AED),
              surface: Color(0xFF1A1535),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(isStart ? _startDate : _endDate),
        builder: (context, child) {
          return Theme(
            data: ThemeData.dark().copyWith(
              colorScheme: const ColorScheme.dark(
                primary: Color(0xFF7C3AED),
                surface: Color(0xFF1A1535),
              ),
            ),
            child: child!,
          );
        },
      );
      if (time != null) {
        final dt = DateTime(
          picked.year, picked.month, picked.day,
          time.hour, time.minute,
        );
        setState(() {
          if (isStart) _startDate = dt;
          else _endDate = dt;
        });
      }
    }
  }

  Future<void> _createEvent() async {
    if (_titleController.text.trim().isEmpty) {
      _showSnack('Please enter a title');
      return;
    }
    if (_locationController.text.trim().isEmpty) {
      _showSnack('Please enter a location');
      return;
    }
    if (_cityController.text.trim().isEmpty) {
      _showSnack('Please enter a city');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('Not authenticated');

      await Supabase.instance.client.from('events').insert({
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'category': _selectedCategory,
        'location': _locationController.text.trim(),
        'city': _cityController.text.trim(),
        'start_date': _startDate.toIso8601String(),
        'end_date': _endDate.toIso8601String(),
        'price': double.tryParse(_priceController.text) ?? 0.0,
        'image_url': _imageUrlController.text.trim().isEmpty
            ? 'https://images.unsplash.com/photo-1574155376612-bfa4ed8aabfd?w=800&h=450&fit=crop'
            : _imageUrlController.text.trim(),
        'created_by': user.id,
      });

      if (mounted) {
        _showSnack('Event created successfully! 🎉');
        await Future.delayed(const Duration(seconds: 1));
        Navigator.of(context).pop(true); // true = refresh home
      }
    } catch (e) {
      _showSnack('Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.inter(color: Colors.white)),
        backgroundColor: const Color(0xFF1A1535),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  InputDecoration _inputDec(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(color: Colors.white.withOpacity(0.25), fontSize: 14),
      prefixIcon: Icon(icon, color: Colors.white.withOpacity(0.3), size: 18),
      filled: true,
      fillColor: Colors.white.withOpacity(0.055),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.09)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.09)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} at ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF08080F),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -1.0),
            radius: 1.2,
            colors: [Color(0xFF1A0F3D), Color(0xFF08080F)],
            stops: [0.0, 0.6],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withOpacity(0.09)),
                        ),
                        child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 16),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      'Create Event',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Form
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // Title
                      _label('Event Title *'),
                      TextField(
                        controller: _titleController,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: _inputDec('e.g. Afro Vibes Party', Icons.title),
                      ),

                      const SizedBox(height: 16),

                      // Category
                      _label('Category *'),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.055),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white.withOpacity(0.09)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedCategory,
                            isExpanded: true,
                            dropdownColor: const Color(0xFF1A1535),
                            style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                            icon: Icon(Icons.keyboard_arrow_down, color: Colors.white.withOpacity(0.4)),
                            items: _categories.map((cat) => DropdownMenuItem(
                              value: cat,
                              child: Text(cat),
                            )).toList(),
                            onChanged: (val) => setState(() => _selectedCategory = val!),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Description
                      _label('Description'),
                      TextField(
                        controller: _descriptionController,
                        maxLines: 3,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: _inputDec('Tell people about your event...', Icons.description_outlined)
                            .copyWith(prefixIcon: null, contentPadding: const EdgeInsets.all(16)),
                      ),

                      const SizedBox(height: 16),

                      // Location + City
                      _label('Location *'),
                      TextField(
                        controller: _locationController,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: _inputDec('Venue name or address', Icons.location_on_outlined),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _cityController,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: _inputDec('City (e.g. Ottawa, ON)', Icons.location_city_outlined),
                      ),

                      const SizedBox(height: 16),

                      // Dates
                      _label('Date & Time *'),
                      Row(
                        children: [
                          Expanded(child: _dateTile('Start', _startDate, () => _pickDate(isStart: true))),
                          const SizedBox(width: 10),
                          Expanded(child: _dateTile('End', _endDate, () => _pickDate(isStart: false))),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Price
                      _label('Price (CAD)'),
                      TextField(
                        controller: _priceController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: _inputDec('0 for free event', Icons.attach_money),
                      ),

                      const SizedBox(height: 16),

                      // Image URL
                      _label('Cover Image URL'),
                      TextField(
                        controller: _imageUrlController,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: _inputDec('https://... (optional)', Icons.image_outlined),
                      ),

                      const SizedBox(height: 8),
                      Text(
                        'Leave empty to use a default image. Supabase Storage upload coming soon.',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.white.withOpacity(0.3),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Submit button
                      GestureDetector(
                        onTap: _isLoading ? null : _createEvent,
                        child: Container(
                          width: double.infinity,
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF7C3AED), Color(0xFFEC4899)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF7C3AED).withOpacity(0.55),
                                blurRadius: 20,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Center(
                            child: _isLoading
                                ? const SizedBox(
                                    width: 24, height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2,
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.rocket_launch, color: Colors.white, size: 18),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Publish Event',
                                        style: GoogleFonts.poppins(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 40),
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

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.white.withOpacity(0.6),
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _dateTile(String label, DateTime dt, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.055),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.09)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                color: Colors.white.withOpacity(0.4),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatDate(dt),
              style: GoogleFonts.inter(
                fontSize: 11,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}