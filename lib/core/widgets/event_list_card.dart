import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:happyn/core/categories/category_visuals.dart';
import 'package:happyn/features/events/event_detail_screen.dart';

/// Carte d'event en ligne (vignette + badge date + titre + lieu + cœur/prix).
/// Partagée par le Home (« Popular near you ») et Discover.
class EventListCard extends StatefulWidget {
  final Map<String, dynamic> event;
  const EventListCard({super.key, required this.event});

  @override
  State<EventListCard> createState() => _EventListCardState();
}

class _EventListCardState extends State<EventListCard> {
  bool _liked = false;

  (String, String) _dateParts(String? s) {
    if (s == null) return ('', '');
    final dt = DateTime.parse(s);
    const m = [
      'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
      'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'
    ];
    return (m[dt.month - 1], dt.day.toString());
  }

  @override
  Widget build(BuildContext context) {
    final ev = widget.event;
    final cat = (ev['category'] ?? '') as String;
    final color = categoryColor(cat);
    final (mon, day) = _dateParts(ev['start_date'] as String?);
    final priceText = (ev['price'] == 0 || ev['price'] == null)
        ? 'Free'
        : '\$${ev['price']}';
    final city = (ev['city'] ?? '') as String;
    final venue = (ev['location'] ?? '') as String;

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => EventDetailScreen(event: ev)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
        ),
        child: Row(
          children: [
            // Vignette + badge date
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                children: [
                  SizedBox(
                    width: 58,
                    height: 58,
                    child: CachedNetworkImage(
                      imageUrl: (ev['image_url'] ?? '') as String,
                      fit: BoxFit.cover,
                      placeholder: (_, _) =>
                          Container(color: const Color(0xFF1A0F3D)),
                      errorWidget: (_, _, _) => Container(
                        color: const Color(0xFF1A0F3D),
                        child: Icon(categoryIcon(cat),
                            color: const Color(0xFF7C3AED), size: 22),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      color: Colors.black.withOpacity(0.55),
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        '$mon $day',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Infos
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    (ev['title'] ?? '') as String,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(categoryIcon(cat), size: 11, color: color),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          venue.isNotEmpty ? venue : cat,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: Colors.white.withOpacity(0.55),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (city.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      city,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: Colors.white.withOpacity(0.38),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Cœur + prix
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () => setState(() => _liked = !_liked),
                  child: Icon(
                    _liked ? Icons.favorite : Icons.favorite_border,
                    color: _liked
                        ? const Color(0xFFEC4899)
                        : Colors.white.withOpacity(0.35),
                    size: 18,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  priceText,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFFC4B5FD),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
