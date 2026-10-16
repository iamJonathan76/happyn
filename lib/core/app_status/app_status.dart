import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:happyn/core/config/store_config.dart';
import 'package:happyn/core/providers/admin_provider.dart';
import 'package:happyn/core/theme/app_colors.dart';
import 'package:happyn/core/theme/app_text.dart';
import 'package:happyn/l10n/app_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// La ligne unique de `app_status` : maintenance et version minimale.
class AppStatus {
  final bool maintenance;
  final String? messageFr;
  final String? messageEn;
  final String? minVersion;

  const AppStatus({
    this.maintenance = false,
    this.messageFr,
    this.messageEn,
    this.minVersion,
  });

  static const open = AppStatus();

  factory AppStatus.fromRow(Map<String, dynamic> r) => AppStatus(
        maintenance: r['maintenance'] == true,
        messageFr: r['message_fr'] as String?,
        messageEn: r['message_en'] as String?,
        minVersion: r['min_version'] as String?,
      );

  String? messageFor(String lang) => lang == 'fr' ? messageFr : messageEn;
}

/// En temps réel : une app ouverte bascule dès que la maintenance est activée
/// ou levée. En cas d'erreur réseau, on laisse passer — une panne de lecture
/// ne doit jamais enfermer tout le monde dehors.
final appStatusProvider = StreamProvider<AppStatus>((ref) {
  return Supabase.instance.client
      .from('app_status')
      .stream(primaryKey: ['id'])
      .map((rows) => rows.isEmpty ? AppStatus.open : AppStatus.fromRow(rows.first))
      .handleError((Object _) {});
});

final appVersionProvider = FutureProvider<String>(
    (ref) async => (await PackageInfo.fromPlatform()).version);

/// « 1.2.10 » contre « 1.10 » : chiffre par chiffre, pas en texte.
bool isOlderThan(String current, String minimum) {
  List<int> parts(String v) =>
      v.split('.').map((p) => int.tryParse(p.split('+').first) ?? 0).toList();
  final a = parts(current), b = parts(minimum);
  for (var i = 0; i < 3; i++) {
    final x = i < a.length ? a[i] : 0, y = i < b.length ? b[i] : 0;
    if (x != y) return x < y;
  }
  return false;
}

/// Posé au-dessus de toute l'app (MaterialApp.builder) : en maintenance ou
/// trop ancienne, l'app montre un seul écran, quelle que soit la page ouverte.
/// Les administrateurs passent la maintenance, pour vérifier avant de rouvrir.
class AppStatusGate extends ConsumerWidget {
  final Widget child;
  const AppStatusGate({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(appStatusProvider).asData?.value ?? AppStatus.open;
    final version = ref.watch(appVersionProvider).asData?.value;

    final min = status.minVersion;
    if (min != null && version != null && isOlderThan(version, min)) {
      return const _UpdateRequiredScreen();
    }
    if (status.maintenance) {
      final isAdmin = ref.watch(isAdminProvider).asData?.value ?? false;
      if (!isAdmin) return _MaintenanceScreen(status: status);
    }
    return child;
  }
}

class _MaintenanceScreen extends StatelessWidget {
  final AppStatus status;
  const _MaintenanceScreen({required this.status});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final custom = status.messageFor(Localizations.localeOf(context).languageCode);
    return _StatusScaffold(
      icon: Icons.construction_rounded,
      title: l.maintenanceTitle,
      body: (custom ?? '').isNotEmpty ? custom! : l.maintenanceBody,
    );
  }
}

class _UpdateRequiredScreen extends StatelessWidget {
  const _UpdateRequiredScreen();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final url = Platform.isIOS ? kAppStoreUrl : kPlayStoreUrl;
    return _StatusScaffold(
      icon: Icons.system_update_rounded,
      title: l.updateRequiredTitle,
      body: l.updateRequiredBody,
      action: url == null
          ? null
          : (l.updateRequiredButton,
              () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)),
    );
  }
}

class _StatusScaffold extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final (String, VoidCallback)? action;

  const _StatusScaffold({
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.35),
            radius: 0.9,
            colors: [Color(0x447C3AED), Color(0x0008080F)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                const Spacer(flex: 3),
                Image.asset('assets/images/logo_h.png', width: 72, height: 72),
                const SizedBox(height: 28),
                Icon(icon, color: AppColors.lavenderLight, size: 30),
                const SizedBox(height: 14),
                Text(title,
                    textAlign: TextAlign.center,
                    style: AppText.h2.copyWith(color: Colors.white)),
                const SizedBox(height: 12),
                Text(body,
                    textAlign: TextAlign.center,
                    style: AppText.body.copyWith(color: AppColors.textMed, height: 1.5)),
                const Spacer(flex: 4),
                if (action != null)
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: action!.$2,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.action,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(action!.$1, style: AppText.h3),
                    ),
                  ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
