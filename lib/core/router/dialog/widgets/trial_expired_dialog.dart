import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/features/intro/widget/intro_page.dart';
import 'package:url_launcher/url_launcher.dart';

class TrialExpiredDialog extends StatelessWidget {
  const TrialExpiredDialog({super.key});

  static const _green = Color(0xFF00E5A0);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF18181B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subColor = isDark ? const Color(0xFF71717A) : const Color(0xFF94A3B8);

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _green.withValues(alpha: 0.12),
              ),
              child: const Icon(Icons.timer_outlined, color: _green, size: 28),
            ),
            const SizedBox(height: 16),
            Text(
              'Trial period ended',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: textColor),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '3 free days have expired.\nSubscribe to continue.',
              style: TextStyle(fontSize: 14, color: subColor, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Buy subscription -- open pricing page
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  context.pop();
                  launchUrl(
                    Uri.parse('https://relokant.net/#pricing'),
                    mode: LaunchMode.externalApplication,
                  );
                },
                style: FilledButton.styleFrom(
                  backgroundColor: _green,
                  foregroundColor: const Color(0xFF0a0a0a),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  'Subscribe',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Enter activation code
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  context.pop();
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const CodeEntryPage()),
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: _green,
                  side: BorderSide(color: _green.withValues(alpha: 0.3)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.key, size: 16),
                label: const Text(
                  'Enter activation code',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
