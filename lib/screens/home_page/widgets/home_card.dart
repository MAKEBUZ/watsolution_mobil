import 'package:flutter/material.dart';

class HomeCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color bg;
  final Color fg;
  final VoidCallback? onTap;
  const HomeCard({required this.title, required this.icon, required this.bg, required this.fg, this.onTap, super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        height: 130,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: cs.primary.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: 12,
              bottom: 12,
              child: Icon(icon, color: cs.primary.withValues(alpha: 0.7), size: 28),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: fg,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    ' ',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: fg.withValues(alpha: 0.6)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}