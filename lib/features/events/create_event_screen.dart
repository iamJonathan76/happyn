import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:happyn/core/providers/events_provider.dart';
import 'package:happyn/core/providers/categories_provider.dart';

class CreateEventScreen extends ConsumerStatefulWidget {
  /// Si non-null, l'écran est en mode ÉDITION de cet event (au lieu de création).
  final Map<String, dynamic>? event;
  const CreateEventScreen({super.key, this.event});

  @override
  ConsumerState<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends ConsumerState<CreateEventScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _cityController = TextEditingController();
  // Tiers de billets : 1 par défaut (« General Admission »), l'organisateur
  // peut en ajouter d'autres (VIP, Early Bird…).
  final List<_TicketTier> _tiers = [_TicketTier(name: 'General Admission')];

  XFile? _pickedImage;

  String _selectedCategory = 'Music';
  DateTime _startDate = DateTime.now().add(const Duration(days: 1));
  DateTime _endDate = DateTime.now().add(const Duration(days: 1, hours: 3));
  bool _isLoading = false;

  bool get _isEditing => widget.event != null;

  @override
  void initState() {
    super.initState();
    final ev = widget.event;
    if (ev != null) {
      _titleController.text = (ev['title'] ?? '') as String;
      _descriptionController.text = (ev['description'] ?? '') as String;
      _locationController.text = (ev['location'] ?? '') as String;
      _cityController.text = (ev['city'] ?? '') as String;
      _selectedCategory = (ev['category'] ?? 'Music') as String;
      if (ev['start_date'] != null) {
        _startDate = DateTime.parse(ev['start_date'] as String);
      }
      if (ev['end_date'] != null) {
        _endDate = DateTime.parse(ev['end_date'] as String);
      }
      _loadTiers(ev['id'] as String);
    }
  }

  /// Charge les tiers existants de l'event (mode édition).
  Future<void> _loadTiers(String eventId) async {
    try {
      final data = await Supabase.instance.client
          .from('ticket_types')
          .select()
          .eq('event_id', eventId)
          .order('price');
      final list = List<Map<String, dynamic>>.from(data);
      if (list.isEmpty || !mounted) return;
      setState(() {
        for (final t in _tiers) {
          t.dispose();
        }
        _tiers
          ..clear()
          ..addAll(list.map((t) => _TicketTier(
                id: t['id'] as String,
                name: (t['name'] ?? '') as String,
                price: (t['price'] ?? 0).toString(),
                quantity: (t['quantity_total'] ?? 0).toString(),
                maxPerOrder: (t['max_per_order'] ?? 10).toString(),
                quantitySold: (t['quantity_sold'] ?? 0) as int,
              )));
      });
    } catch (_) {
      // silencieux : on garde le tier par défaut si le chargement échoue
    }
  }


  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _cityController.dispose();
    for (final t in _tiers) {
      t.dispose();
    }
    super.dispose();
  }

  void _addTier() => setState(() => _tiers.add(_TicketTier()));

  void _removeTier(int i) => setState(() => _tiers.removeAt(i).dispose());

  Widget _tierCard(int i) {
    final tier = _tiers[i];
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.09)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: tier.nameController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: _inputDec(
                      'Tier name (e.g. VIP)', Icons.local_activity_outlined),
                ),
              ),
              // Supprimer : seulement les tiers nouveaux (pas ceux qui existent
              // déjà en base, pour ne pas casser des ventes).
              if (tier.id == null && _tiers.length > 1) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _removeTier(i),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF4B4B).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.close,
                        color: Color(0xFFFF4B4B), size: 18),
                  ),
                ),
              ],
            ],
          ),
          if (tier.quantitySold > 0) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${tier.quantitySold} sold · min quantity ${tier.quantitySold}',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: const Color(0xFFA78BFA),
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: tier.priceController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: _inputDec('0 = free', Icons.attach_money),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: tier.quantityController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: _inputDec(
                      'Qty e.g. 100', Icons.confirmation_number_outlined),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: tier.maxPerOrderController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration:
                      _inputDec('Max/person (0=∞)', Icons.person_outline),
                ),
              ),
            ],
          ),
        ],
      ),
    );
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

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1280,
      imageQuality: 80,
    );
    if (picked != null) {
      setState(() => _pickedImage = picked);
    }
  }

  /// Upload l'image choisie dans le bucket `events` et renvoie son URL publique.
  Future<String?> _uploadImage(String userId) async {
    final image = _pickedImage;
    if (image == null) return null;

    final bytes = await image.readAsBytes();
    final ext = image.name.contains('.') ? image.name.split('.').last : 'jpg';
    final path = '$userId/${DateTime.now().millisecondsSinceEpoch}.$ext';

    await Supabase.instance.client.storage.from('events').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: image.mimeType ?? 'image/jpeg',
            upsert: false,
          ),
        );

    return Supabase.instance.client.storage.from('events').getPublicUrl(path);
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

    // ── Mode ÉDITION : infos de l'event + tiers (update/insert) ─────────────
    if (_isEditing) {
      // Construit et valide les tiers
      final editTiers = <_TicketTier>[];
      for (final t in _tiers) {
        final name = t.nameController.text.trim();
        final qty = int.tryParse(t.quantityController.text) ?? 0;
        if (name.isEmpty || qty <= 0) continue;
        // Garde-fou : on ne descend pas sous le nombre déjà vendu.
        if (t.id != null && qty < t.quantitySold) {
          _showSnack('“$name”: quantity can’t be below ${t.quantitySold} sold');
          return;
        }
        editTiers.add(t);
      }
      if (editTiers.isEmpty) {
        _showSnack('Keep at least one ticket tier');
        return;
      }
      final eventPrice = editTiers
          .map((t) => double.tryParse(t.priceController.text) ?? 0.0)
          .reduce((a, b) => a < b ? a : b);

      setState(() => _isLoading = true);
      try {
        final userId = Supabase.instance.client.auth.currentUser!.id;
        final imageUrl = _pickedImage != null
            ? await _uploadImage(userId)
            : (widget.event!['image_url'] as String?);
        final eventId = widget.event!['id'];

        await Supabase.instance.client.from('events').update({
          'title': _titleController.text.trim(),
          'description': _descriptionController.text.trim(),
          'category': _selectedCategory,
          'location': _locationController.text.trim(),
          'city': _cityController.text.trim(),
          'start_date': _startDate.toIso8601String(),
          'end_date': _endDate.toIso8601String(),
          'price': eventPrice,
          if (imageUrl != null) 'image_url': imageUrl,
        }).eq('id', eventId);

        // Upsert des tiers : update si existant, insert si nouveau.
        for (final t in editTiers) {
          final qty = int.parse(t.quantityController.text);
          final maxRaw = int.tryParse(t.maxPerOrderController.text) ?? 0;
          final maxPer = maxRaw <= 0 ? qty : maxRaw;
          final payload = {
            'name': t.nameController.text.trim(),
            'price': double.tryParse(t.priceController.text) ?? 0.0,
            'quantity_total': qty,
            'max_per_order': maxPer,
          };
          if (t.id != null) {
            await Supabase.instance.client
                .from('ticket_types')
                .update(payload)
                .eq('id', t.id!);
          } else {
            await Supabase.instance.client.from('ticket_types').insert(
              {...payload, 'event_id': eventId, 'quantity_sold': 0},
            );
          }
        }

        if (mounted) {
          ref.invalidate(eventsProvider);
          _showSnack('Event updated ✓');
          await Future.delayed(const Duration(milliseconds: 800));
          if (mounted) Navigator.of(context).pop(true);
        }
      } catch (e) {
        _showSnack('Error: ${e.toString()}');
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
      return;
    }

    // Valide et construit les tiers de billets (nom + quantité requis)
    final tiers = <Map<String, dynamic>>[];
    for (final t in _tiers) {
      final name = t.nameController.text.trim();
      final qty = int.tryParse(t.quantityController.text) ?? 0;
      if (name.isEmpty || qty <= 0) continue;
      // 0 ou vide = pas de limite par personne → plafonné par le stock (qty).
      final maxRaw = int.tryParse(t.maxPerOrderController.text) ?? 0;
      final maxPer = maxRaw <= 0 ? qty : maxRaw;
      tiers.add({
        'name': name,
        'price': double.tryParse(t.priceController.text) ?? 0.0,
        'quantity_total': qty,
        'quantity_sold': 0,
        'max_per_order': maxPer,
      });
    }
    if (tiers.isEmpty) {
      _showSnack('Add at least one ticket tier (name + quantity)');
      return;
    }
    // Prix affiché de l'event = le tier le moins cher (« Starting from »)
    final eventPrice = tiers
        .map((t) => t['price'] as double)
        .reduce((a, b) => a < b ? a : b);

    setState(() => _isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('Not authenticated');

      // Upload de l'image (si choisie) → URL publique, sinon image par défaut.
      final uploadedUrl = await _uploadImage(user.id);
      final imageUrl = uploadedUrl ??
          'https://images.unsplash.com/photo-1574155376612-bfa4ed8aabfd?w=800&h=450&fit=crop';

      // 1. Crée l'event et récupère son id
      final createdEvent = await Supabase.instance.client
          .from('events')
          .insert({
            'title': _titleController.text.trim(),
            'description': _descriptionController.text.trim(),
            'category': _selectedCategory,
            'location': _locationController.text.trim(),
            'city': _cityController.text.trim(),
            'start_date': _startDate.toIso8601String(),
            'end_date': _endDate.toIso8601String(),
            'price': eventPrice,
            'image_url': imageUrl,
            'created_by': user.id,
          })
          .select()
          .single();

      // 2. Crée tous les tiers de billets liés à l'event
      final ticketRows = tiers
          .map((t) => {...t, 'event_id': createdEvent['id']})
          .toList();
      await Supabase.instance.client.from('ticket_types').insert(ticketRows);

      if (mounted) {
        // Invalide le provider partagé : Home, Discover et Profile
        // verront le nouvel event automatiquement, sans relancer l'app.
        ref.invalidate(eventsProvider);
        _showSnack('Event created successfully! 🎉');
        await Future.delayed(const Duration(seconds: 1));
        Navigator.of(context).pop(true); // true = signal optionnel pour l'appelant
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
    final categoryNames = ref.watch(categoryNamesProvider);
    // Fallback tant que la table n'est pas chargée, pour ne pas casser le menu.
    final cats = categoryNames.isEmpty ? [_selectedCategory] : categoryNames;
    final dropdownValue =
        cats.contains(_selectedCategory) ? _selectedCategory : cats.first;

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
                      _isEditing ? 'Edit Event' : 'Create Event',
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
                            value: dropdownValue,
                            isExpanded: true,
                            dropdownColor: const Color(0xFF1A1535),
                            style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                            icon: Icon(Icons.keyboard_arrow_down, color: Colors.white.withOpacity(0.4)),
                            items: cats.map((cat) => DropdownMenuItem(
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

                      // Ticket tiers (création + édition : augmenter la quantité,
                      // changer le prix/max, ajouter un tier)
                      ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _label('Ticket Tiers *'),
                            GestureDetector(
                              onTap: _addTier,
                              child: Row(
                                children: [
                                  const Icon(Icons.add,
                                      color: Color(0xFFA78BFA), size: 16),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Add tier',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFFA78BFA),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        ...List.generate(_tiers.length, (i) => _tierCard(i)),
                        const SizedBox(height: 16),
                      ],

                      // Cover image picker
                      _label('Cover Image'),
                      GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          height: 160,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.09)),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: _pickedImage == null
                              ? (_isEditing &&
                                      ((widget.event!['image_url'] ?? '')
                                              as String)
                                          .isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl:
                                          widget.event!['image_url'] as String,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                    )
                                  : Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                            Icons.add_photo_alternate_outlined,
                                            color: Colors.white.withOpacity(0.4),
                                            size: 36),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Tap to choose a cover photo',
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            color: Colors.white.withOpacity(0.4),
                                          ),
                                        ),
                                      ],
                                    ))
                              : Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image.file(File(_pickedImage!.path),
                                        fit: BoxFit.cover),
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: GestureDetector(
                                        onTap: () => setState(
                                            () => _pickedImage = null),
                                        child: Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(0.6),
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          child: const Icon(Icons.close,
                                              color: Colors.white, size: 16),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Optional — a default image is used if you skip this.',
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
                                      Icon(
                                          _isEditing
                                              ? Icons.check_circle_outline
                                              : Icons.rocket_launch,
                                          color: Colors.white,
                                          size: 18),
                                      const SizedBox(width: 8),
                                      Text(
                                        _isEditing
                                            ? 'Save Changes'
                                            : 'Publish Event',
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

/// Un tier de billet en cours d'édition dans Create Event (nom, prix, quantité).
class _TicketTier {
  /// id du ticket_type existant (null = nouveau tier à créer).
  final String? id;

  /// Nombre déjà vendu (garde-fou : on ne descend pas la quantité en dessous).
  final int quantitySold;

  final TextEditingController nameController;
  final TextEditingController priceController;
  final TextEditingController quantityController;
  final TextEditingController maxPerOrderController;

  _TicketTier({
    String name = '',
    this.id,
    this.quantitySold = 0,
    String price = '',
    String quantity = '100',
    String maxPerOrder = '10',
  })  : nameController = TextEditingController(text: name),
        priceController = TextEditingController(text: price),
        quantityController = TextEditingController(text: quantity),
        maxPerOrderController = TextEditingController(text: maxPerOrder);

  void dispose() {
    nameController.dispose();
    priceController.dispose();
    quantityController.dispose();
    maxPerOrderController.dispose();
  }
}