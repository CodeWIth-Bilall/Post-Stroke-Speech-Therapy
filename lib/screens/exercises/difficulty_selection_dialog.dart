import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';
import '../../utils/constants.dart';

/// Shows a bottom-sheet difficulty picker and returns the chosen level
/// (1 = Easy, 2 = Medium, 3 = Hard), or null if dismissed.
Future<int?> showDifficultySelection(BuildContext context, String gameTitle) {
  return showModalBottomSheet<int>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    backgroundColor: AppTheme.scaffoldBg,
    builder: (ctx) => _DifficultySheet(gameTitle: gameTitle),
  );
}

class _DifficultySheet extends StatelessWidget {
  final String gameTitle;
  const _DifficultySheet({required this.gameTitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            gameTitle,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Choose your difficulty level',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 24),

          // Easy
          _DifficultyTile(
            level: AppConstants.difficultyEasy,
            title: 'Easy',
            subtitle: 'Standard words, no time limit',
            icon: Icons.sentiment_satisfied_rounded,
            color: AppTheme.success,
            onTap: () => Navigator.pop(context, AppConstants.difficultyEasy),
          ),
          const SizedBox(height: 12),

          // Medium
          _DifficultyTile(
            level: AppConstants.difficultyMedium,
            title: 'Medium',
            subtitle: '5-second timer per attempt',
            icon: Icons.timer_rounded,
            color: AppTheme.warning,
            onTap: () => Navigator.pop(context, AppConstants.difficultyMedium),
          ),
          const SizedBox(height: 12),

          // Hard
          _DifficultyTile(
            level: AppConstants.difficultyHard,
            title: 'Hard',
            subtitle: 'Similar-sounding word pairs',
            icon: Icons.local_fire_department_rounded,
            color: AppTheme.error,
            onTap: () => Navigator.pop(context, AppConstants.difficultyHard),
          ),
        ],
      ),
    );
  }
}

class _DifficultyTile extends StatelessWidget {
  final int level;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _DifficultyTile({
    required this.level,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: color.withOpacity(0.5), size: 18),
          ],
        ),
      ),
    );
  }
}
