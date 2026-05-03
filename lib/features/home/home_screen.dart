import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../widgets/glass_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Music Player',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'অডিও টাবে ফোনের গান, ভিডিও টাবে গ্যালারির ভিডিও — অ্যাপ খুললেই লোড হয়। Music ও Photos/Videos অনুমতি দিন; লিস্ট খালি থাকলে অডিও/ভিডিও ট্যাবে রিফ্রেশ চাপুন।',
                  style: TextStyle(
                    height: 1.45,
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverToBoxAdapter(
            child: GlassCard(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Icon(Icons.graphic_eq_rounded, color: cs.secondary, size: 32),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ব্যাকগ্রাউন্ড প্লে',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colors.white.withValues(alpha: 0.95),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'প্লে চালু রেখে অন্য অ্যাপ বা লক স্ক্রিন — নোটিফিকেশন থেকে নিয়ন্ত্রণ করুন।',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.65),
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 20)),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                Expanded(
                  child: _HubTile(
                    icon: Icons.audiotrack_rounded,
                    title: 'অডিও',
                    subtitle: 'গান ও পডকাস্ট',
                    gradient: [
                      AppColors.violetGlow.withValues(alpha: 0.85),
                      AppColors.roseAccent.withValues(alpha: 0.55),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _HubTile(
                    icon: Icons.ondemand_video_rounded,
                    title: 'ভিডিও',
                    subtitle: 'ফুল স্ক্রিন বা শুধু শব্দ',
                    gradient: [
                      AppColors.cyanAccent.withValues(alpha: 0.75),
                      AppColors.violetGlow.withValues(alpha: 0.55),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 28)),
      ],
    );
  }
}

class _HubTile extends StatelessWidget {
  const _HubTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> gradient;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(colors: gradient),
            ),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 13,
              height: 1.35,
              color: Colors.white.withValues(alpha: 0.65),
            ),
          ),
        ],
      ),
    );
  }
}
