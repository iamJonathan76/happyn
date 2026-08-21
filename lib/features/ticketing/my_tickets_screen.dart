import 'package:flutter/material.dart';
import 'widgets/ticket_card.dart';
import 'package:happyn/core/theme/app_text.dart';
import 'package:happyn/core/theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:happyn/core/providers/tickets_provider.dart';
import 'qr_ticket_screen.dart';
import 'package:happyn/l10n/app_localizations.dart';

class MyTicketsScreen extends ConsumerStatefulWidget {
  const MyTicketsScreen({super.key});

  @override
  ConsumerState<MyTicketsScreen> createState() => _MyTicketsScreenState();
}

class _MyTicketsScreenState extends ConsumerState<MyTicketsScreen> {
  int _selectedTab = 0; // 0 = upcoming, 1 = past

  List<Map<String, dynamic>> _filtered(List<Map<String, dynamic>> tickets) {
    final now = DateTime.now();
    return tickets.where((t) {
      final event = t['events'] as Map<String, dynamic>?;
      if (event == null) return false;
      final startDate = event['start_date'];
      if (startDate == null) return _selectedTab == 0;
      final eventDate = DateTime.parse(startDate as String);
      return _selectedTab == 0
          ? eventDate.isAfter(now)
          : eventDate.isBefore(now);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final ticketsAsync = ref.watch(myTicketsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          SizedBox(height: MediaQuery.of(context).padding.top),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                l.myTicketsTitle,
                style: AppText.display.copyWith(color: Colors.white),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [l.tabUpcoming, l.tabPast].asMap().entries.map((e) {
                final isActive = e.key == _selectedTab;
                return GestureDetector(
                  onTap: () => setState(() => _selectedTab = e.key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: isActive
                          ? const LinearGradient(
                              colors: [AppColors.primary, AppColors.pink],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: isActive ? null : Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: isActive
                          ? null
                          : Border.all(color: Colors.white.withOpacity(0.09)),
                    ),
                    child: Text(
                      e.value,
                      style: AppText.caption.copyWith(fontWeight: FontWeight.w700, color: isActive
                            ? Colors.white
                            : AppColors.textLow),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 16),

          // Content
          Expanded(
            child: ticketsAsync.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.primary)),
              error: (_, __) => _buildEmptyState(),
              data: (all) {
                final filtered = _filtered(all);
                return RefreshIndicator(
                  color: AppColors.primary,
                  backgroundColor: AppColors.card,
                  onRefresh: () async {
                    ref.invalidate(myTicketsProvider);
                    await ref.read(myTicketsProvider.future);
                  },
                  child: filtered.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(
                                height: 360, child: _buildEmptyState()),
                          ],
                        )
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding:
                              const EdgeInsets.fromLTRB(20, 0, 20, 90),
                          itemCount: filtered.length,
                          itemBuilder: (context, i) => TicketCard(
                            ticket: filtered[i],
                            onTap: () => _openTicket(filtered[i]),
                          ),
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _openTicket(Map<String, dynamic> ticket) {
    final event = ticket['events'] as Map<String, dynamic>? ?? {};
    final ticketType = ticket['ticket_types'] as Map<String, dynamic>? ?? {};

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QrTicketScreen(
          ticket: ticket,
          event: event,
          ticketType: ticketType,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final l = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.confirmation_number_outlined,
              size: 52, color: AppColors.textFaint),
          const SizedBox(height: 16),
          Text(
            _selectedTab == 0
                ? l.noUpcomingTickets
                : l.noPastTickets,
            style: AppText.body.copyWith(color: AppColors.textLow),
          ),
          const SizedBox(height: 8),
          Text(
            l.discoverAndBuy,
            style: AppText.caption.copyWith(color: AppColors.textFaint),
          ),
        ],
      ),
    );
  }
}


