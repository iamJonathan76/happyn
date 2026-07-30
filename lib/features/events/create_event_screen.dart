import 'dart:io';
import 'package:happyn/core/theme/app_text.dart';
import 'package:happyn/core/theme/app_colors.dart';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:happyn/core/providers/events_provider.dart';
import 'package:happyn/core/utils/age.dart';
import 'package:happyn/l10n/app_localizations.dart';
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

  /// Event privé : non listé dans la découverte, accessible seulement via code.
  bool _isPrivate = false;
  /// Code existant (mode édition) pour ne pas en regénérer un inutilement.
  String? _existingCode;
  /// Exigence d'âge (0 = All Ages, sinon 14/16/18/21).
  int _minAge = 0;

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
      _isPrivate = (ev['visibility'] ?? 'public') == 'private';
      _existingCode = ev['access_code'] as String?;
      _minAge = (ev['min_age'] ?? 0) as int;
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
    final l = AppLocalizations.of(context);
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
                      l.tierNameHint, Icons.local_activity_outlined),
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
                      color: AppColors.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.close,
                        color: AppColors.error, size: 18),
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
                l.tierSoldInfo(tier.quantitySold),
                style: AppText.micro.copyWith(color: AppColors.lavender),
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
                  decoration: _inputDec(l.priceFreeHint, Icons.attach_money),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: tier.quantityController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: _inputDec(
                      l.qtyHint, Icons.confirmation_number_outlined),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: tier.maxPerOrderController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration:
                      _inputDec(l.maxPerPersonHint, Icons.person_outline),
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
              primary: AppColors.primary,
              surface: AppColors.card,
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
                primary: AppColors.primary,
                surface: AppColors.card,
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
    final l = AppLocalizations.of(context);
    // Gate 18+ : organiser un event requiert la majorité. Soft : si l'âge est
    // inconnu (ancien compte sans date de naissance), on laisse passer.
    final age = currentUserAge();
    if (age != null && age < kMinOrganizerAge) {
      _showSnack(l.mustBeOrganizerAge(kMinOrganizerAge));
      return;
    }
    if (_titleController.text.trim().isEmpty) {
      _showSnack(l.errEnterTitle);
      return;
    }
    if (_locationController.text.trim().isEmpty) {
      _showSnack(l.errEnterLocation);
      return;
    }
    if (_cityController.text.trim().isEmpty) {
      _showSnack(l.errEnterCity);
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
          _showSnack(l.errQtyBelowSold(name, t.quantitySold));
          return;
        }
        editTiers.add(t);
      }
      if (editTiers.isEmpty) {
        _showSnack(l.errKeepOneTier);
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

        // Passage en privé : on génère un code s'il n'en existe pas encore.
        final editCode = _isPrivate
            ? (_existingCode ?? _generateCode())
            : null;

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
          'visibility': _isPrivate ? 'private' : 'public',
          'access_code': editCode, // null si repassé en public
          'min_age': _minAge,
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
          // Si on vient de passer l'event en privé, on montre le code.
          if (editCode != null && _existingCode == null) {
            _existingCode = editCode;
            await _showInviteDialog(_titleController.text.trim(), editCode);
          } else {
            _showSnack(l.eventUpdated);
            await Future.delayed(const Duration(milliseconds: 800));
          }
          if (mounted) Navigator.of(context).pop(true);
        }
      } catch (e) {
        _showSnack(l.errGeneric(e.toString()));
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
      _showSnack(l.errAddOneTier);
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

      // Code d'invitation généré uniquement pour les events privés.
      final accessCode = _isPrivate ? _generateCode() : null;

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
            'visibility': _isPrivate ? 'private' : 'public',
            'min_age': _minAge,
            if (accessCode != null) 'access_code': accessCode,
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
        // Event privé : on montre le code d'invitation à partager.
        if (accessCode != null) {
          await _showInviteDialog(_titleController.text.trim(), accessCode);
        } else {
          _showSnack(l.eventCreated);
          await Future.delayed(const Duration(seconds: 1));
        }
        if (mounted) {
          Navigator.of(context).pop(true); // signal optionnel pour l'appelant
        }
      }
    } catch (e) {
      _showSnack(l.errGeneric(e.toString()));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Génère un code d'invitation court et lisible : HPN-XXXXX
  /// (sans caractères ambigus : ni O/0, ni I/1).
  String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random.secure();
    final code =
        List.generate(5, (_) => chars[rand.nextInt(chars.length)]).join();
    return 'HPN-$code';
  }

  /// Affiche le code après création d'un event privé, avec copie/partage.
  Future<void> _showInviteDialog(String title, String code) async {
    final l = AppLocalizations.of(context);
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => Dialog(
        backgroundColor: AppColors.sheet,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline,
                  color: AppColors.lavenderLight, size: 34),
              const SizedBox(height: 12),
              Text(
                l.privateEventCreated,
                textAlign: TextAlign.center,
                style: AppText.h2.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 6),
              Text(
                l.privateEventCreatedBody,
                textAlign: TextAlign.center,
                style: AppText.bodySm.copyWith(fontSize: 12.5, height: 1.4),
              ),
              const SizedBox(height: 18),
              // Code
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: AppColors.primary.withOpacity(0.4)),
                ),
                child: Center(
                  child: Text(
                    code,
                    style: AppText.display.copyWith(color: Colors.white, letterSpacing: 2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: code));
                        _showSnack(l.codeCopied);
                      },
                      icon: const Icon(Icons.copy,
                          size: 16, color: Colors.white),
                      label: Text(l.copyCode,
                          style: AppText.body.copyWith(fontWeight: FontWeight.w600, color: Colors.white)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(
                            color: AppColors.textFaint),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(
                            text: l.inviteShareText(title, code)));
                        _showSnack(l.inviteCopied);
                      },
                      icon: const Icon(Icons.ios_share,
                          size: 16, color: Colors.white),
                      label: Text(l.share,
                          style: AppText.body.copyWith(fontWeight: FontWeight.w700, color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(),
                child: Text(l.done,
                    style: AppText.body),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: AppText.body.copyWith(color: Colors.white)),
        backgroundColor: AppColors.card,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  InputDecoration _inputDec(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppText.body.copyWith(color: AppColors.textFaint),
      prefixIcon: Icon(icon, color: AppColors.textLow, size: 18),
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
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} at ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final categoryNames = ref.watch(categoryNamesProvider);
    // Fallback tant que la table n'est pas chargée, pour ne pas casser le menu.
    final cats = categoryNames.isEmpty ? [_selectedCategory] : categoryNames;
    final dropdownValue =
        cats.contains(_selectedCategory) ? _selectedCategory : cats.first;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -1.0),
            radius: 1.2,
            colors: [AppColors.imagePlaceholder, AppColors.background],
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
                      _isEditing ? l.editEventTitle : l.createEventTitle,
                      style: AppText.h1.copyWith(color: Colors.white),
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
                      _label(l.eventTitleLabel),
                      TextField(
                        controller: _titleController,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: _inputDec('e.g. Afro Vibes Party', Icons.title),
                      ),

                      const SizedBox(height: 16),

                      // Category
                      _label(l.categoryLabel),
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
                            dropdownColor: AppColors.card,
                            style: AppText.body.copyWith(color: Colors.white),
                            icon: Icon(Icons.keyboard_arrow_down, color: AppColors.textLow),
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
                      _label(l.descriptionLabel),
                      TextField(
                        controller: _descriptionController,
                        maxLines: 3,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: _inputDec(l.descriptionHint, Icons.description_outlined)
                            .copyWith(prefixIcon: null, contentPadding: const EdgeInsets.all(16)),
                      ),

                      const SizedBox(height: 16),

                      // Location + City
                      _label(l.locationLabel),
                      TextField(
                        controller: _locationController,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: _inputDec(l.venueHint, Icons.location_on_outlined),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _cityController,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: _inputDec(l.cityHint, Icons.location_city_outlined),
                      ),

                      const SizedBox(height: 16),

                      // Dates
                      _label(l.dateTimeLabel),
                      Row(
                        children: [
                          Expanded(child: _dateTile(l.startLabel, _startDate, () => _pickDate(isStart: true))),
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
                            _label(l.ticketTiersLabel),
                            GestureDetector(
                              onTap: _addTier,
                              child: Row(
                                children: [
                                  const Icon(Icons.add,
                                      color: AppColors.lavender, size: 16),
                                  const SizedBox(width: 4),
                                  Text(
                                    l.addTier,
                                    style: AppText.caption.copyWith(fontWeight: FontWeight.w700, color: AppColors.lavender),
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
                      _label(l.coverImageLabel),
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
                                            color: AppColors.textLow,
                                            size: 36),
                                        const SizedBox(height: 8),
                                        Text(
                                          l.tapToChoosePhoto,
                                          style: AppText.caption.copyWith(color: AppColors.textLow),
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
                        l.coverOptional,
                        style: AppText.small,
                      ),

                      const SizedBox(height: 24),

                      // ── Exigence d'âge ─────────────────────────────
                      _label(l.ageRequirementLabel),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _ageChip(0, l.allAges),
                          _ageChip(14, '14+'),
                          _ageChip(16, '16+'),
                          _ageChip(18, '18+'),
                          _ageChip(21, '21+'),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Attendees below the age are blocked at checkout. Final '
                        'age check is done at the door by the organizer.',
                        style: AppText.small,
                      ),

                      const SizedBox(height: 24),

                      // ── Event privé ────────────────────────────────
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _isPrivate
                                ? AppColors.primary.withOpacity(0.5)
                                : Colors.white.withOpacity(0.07),
                          ),
                        ),
                        child: Column(
                          children: [
                            SwitchListTile(
                              value: _isPrivate,
                              onChanged: (v) => setState(() => _isPrivate = v),
                              activeColor: AppColors.primary,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 2),
                              title: Row(
                                children: [
                                  Icon(
                                    _isPrivate
                                        ? Icons.lock
                                        : Icons.public,
                                    size: 16,
                                    color: AppColors.textMed,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    l.privateEventLabel,
                                    style: AppText.h4.copyWith(color: Colors.white),
                                  ),
                                ],
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  _isPrivate
                                      ? l.privateEventOnHelp
                                      : l.privateEventOffHelp,
                                  style: AppText.caption.copyWith(fontSize: 11.5, height: 1.35),
                                ),
                              ),
                            ),
                            // Mode édition : rappel du code existant
                            if (_isEditing &&
                                _isPrivate &&
                                _existingCode != null)
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 0, 16, 14),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        l.inviteCodeLabel(_existingCode!),
                                        style: AppText.h5.copyWith(color: AppColors.lavenderLight, letterSpacing: 1),
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () {
                                        Clipboard.setData(ClipboardData(
                                            text: _existingCode!));
                                        _showSnack(l.codeCopied);
                                      },
                                      child: Icon(Icons.copy,
                                          size: 16,
                                          color: Colors.white
                                              .withOpacity(0.5)),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 28),

                      // Submit button
                      GestureDetector(
                        onTap: _isLoading ? null : _createEvent,
                        child: Container(
                          width: double.infinity,
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.primary, AppColors.pink],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.55),
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
                                            ? l.saveChanges
                                            : l.publishEvent,
                                        style: AppText.h3.copyWith(color: Colors.white),
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

  Widget _ageChip(int value, String label) {
    final selected = _minAge == value;
    return GestureDetector(
      onTap: () => setState(() => _minAge = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  colors: [AppColors.primary, AppColors.pink])
              : null,
          color: selected ? null : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected
                  ? Colors.transparent
                  : Colors.white.withOpacity(0.09)),
        ),
        child: Text(
          label,
          style: AppText.bodySm.copyWith(fontWeight: FontWeight.w700, color: selected ? Colors.white : AppColors.textMed),
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: AppText.captionBold.copyWith(color: AppColors.textMed, letterSpacing: 0.3),
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
              style: AppText.micro.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              _formatDate(dt),
              style: AppText.small.copyWith(fontWeight: FontWeight.w600, color: Colors.white),
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