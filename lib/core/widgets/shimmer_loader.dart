import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../theme/app_theme.dart';

class ShimmerLoader extends StatelessWidget {
  final double width;
  final double height;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry margin;

  const ShimmerLoader({
    super.key,
    this.width = double.infinity,
    this.height = 100,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.margin = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      child: Shimmer.fromColors(
        baseColor: AppTheme.surfaceColor.withValues(alpha: 0.1),
        highlightColor: AppTheme.backgroundColor.withValues(alpha: 0.2),
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: borderRadius,
          ),
        ),
      ),
    );
  }
}

class ShimmerList extends StatelessWidget {
  final int count;
  final double height;

  const ShimmerList({super.key, this.count = 3, this.height = 120});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: count,
      itemBuilder: (context, index) {
        return ShimmerLoader(
          height: height,
          margin: const EdgeInsets.only(bottom: 16),
        );
      },
    );
  }
}