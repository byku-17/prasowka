import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class NewsSkeleton extends StatelessWidget {
  final bool isSmall;

  const NewsSkeleton({super.key, this.isSmall = false});

  @override
  Widget build(BuildContext context) {
    if (isSmall) return _buildSmallSkeleton(context);
    return _buildEdgeToEdgeSkeleton(context);
  }

  Widget _buildEdgeToEdgeSkeleton(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.grey[900]! : Colors.grey[300]!;
    final highlightColor = isDark ? Colors.grey[800]! : Colors.grey[100]!;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Zdjęcie na całą szerokość
          Container(
            height: 200,
            width: double.infinity,
            color: baseColor,
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 20, width: double.infinity, color: baseColor),
                const SizedBox(height: 8),
                Container(height: 20, width: 200, color: baseColor),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(height: 10, width: 60, color: baseColor),
                    const Spacer(),
                    Container(height: 14, width: 100, color: baseColor),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white10),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSmallSkeleton(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.grey[900]! : Colors.grey[300]!;
    final highlightColor = isDark ? Colors.grey[800]! : Colors.grey[100]!;

    return Container(
      width: 280,
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Shimmer.fromColors(
        baseColor: baseColor,
        highlightColor: highlightColor,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 150,
              width: 280,
              decoration: BoxDecoration(
                color: baseColor,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(height: 8),
            Container(height: 14, width: 200, color: baseColor),
            const SizedBox(height: 6),
            Container(height: 10, width: 100, color: baseColor),
          ],
        ),
      ),
    );
  }
}
