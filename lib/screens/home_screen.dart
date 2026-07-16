import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:wood_quote/bloc/cubit/estimates_cubit.dart';
import 'package:wood_quote/models/estimate_stats.dart';
import 'package:wood_quote/screens/shared_widgets/custom_appbar.dart';
import 'package:wood_quote/utils/colors.dart';
import '../models/estimate.dart';

class HomeScreen extends StatelessWidget {
  final VoidCallback? onCreatePressed;
  final VoidCallback? onViewEstimatesPressed;

  const HomeScreen({
    super.key,
    this.onCreatePressed,
    this.onViewEstimatesPressed,
  });

  static String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  Future<void> _refresh(BuildContext context) {
    return context.read<EstimatesCubit>().loadEstimates();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: neutral,
      body: BlocBuilder<EstimatesCubit, EstimatesState>(
        builder: (context, state) {
          final bool loading =
              state is EstimatesInitial || state is EstimatesLoading;

          final bool hasError = state is EstimatesError;

          final List<Estimate> estimates = state is EstimatesLoaded
              ? state.estimates
              : <Estimate>[];

          final EstimateStats stats = state is EstimatesLoaded
              ? _calculateStats(estimates)
              : const EstimateStats.empty();

          final List<Estimate> recentEstimates = state is EstimatesLoaded
              ? _recentEstimates(estimates)
              : <Estimate>[];

          if (loading && estimates.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          return RefreshIndicator(
            color: primary,
            onRefresh: () => _refresh(context),
            child: CustomScrollView(
              slivers: [
                CustomAppBar(),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _HeroBanner(_greeting),
                      const SizedBox(height: 20),
                      _CreateButton(onPressed: onCreatePressed),
                      const SizedBox(height: 12),
                      _ViewAllButton(onPressed: onViewEstimatesPressed),
                      const SizedBox(height: 20),

                      if (hasError)
                        _HomeErrorBanner(
                          message: state.errorMessage,
                          onRetry: () => _refresh(context),
                        ),

                      if (hasError) const SizedBox(height: 16),

                      _StatsSection(
                        loading: loading,
                        total: stats.total,
                        shared: stats.shared,
                        drafts: stats.drafts,
                      ),
                      const SizedBox(height: 14),
                      _TotalValueCard(
                        loading: loading,
                        totalValue: stats.totalValue,
                      ),
                      const SizedBox(height: 28),
                      _RecentEstimatesSection(
                        loading: loading,
                        estimates: recentEstimates,
                        onSeeAllTap: onViewEstimatesPressed,
                      ),
                    ]),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  static EstimateStats _calculateStats(List<Estimate> estimates) {
    int drafts = 0;
    int shared = 0;
    int finalised = 0;
    double totalValue = 0;

    for (final estimate in estimates) {
      totalValue += estimate.amount;

      switch (estimate.status) {
        case EstimateStatus.draft:
          drafts++;
          break;
        case EstimateStatus.shared:
          shared++;
          break;
        case EstimateStatus.finalised:
          finalised++;
          break;
      }
    }

    return EstimateStats(
      total: estimates.length,
      drafts: drafts,
      shared: shared,
      finalised: finalised,
      totalValue: totalValue,
    );
  }

  static List<Estimate> _recentEstimates(List<Estimate> estimates) {
    final list = List<Estimate>.from(estimates);

    list.sort((a, b) {
      final dateA = a.date ?? DateTime.fromMillisecondsSinceEpoch(0);
      final dateB = b.date ?? DateTime.fromMillisecondsSinceEpoch(0);

      final result = dateB.compareTo(dateA);
      if (result != 0) return result;

      return (b.id ?? 0).compareTo(a.id ?? 0);
    });

    return list.take(3).toList();
  }
}

class _HeroBanner extends StatelessWidget {
  final String greeting;
  const _HeroBanner(this.greeting);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          height: 190,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            image: DecorationImage(
              image: AssetImage('assets/images/wood.png'),
              fit: BoxFit.cover,
              colorFilter: ColorFilter.mode(
                Colors.white.withValues(alpha: 0.08),
                BlendMode.srcATop,
              ),
            ),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 0.8, sigmaY: 0.8),
            child: Container(color: Colors.transparent),
          ),
        ),
        Positioned(
          bottom: 0,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  '$greeting,\nMr. Raphael 👋',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Ready to craft your next estimate today?',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HomeErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _HomeErrorBanner({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF2F2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFD1D1), width: 0.8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Color(0xFFB3261E),
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF7A1C17),
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _WoodGrainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..strokeWidth = 18
      ..style = PaintingStyle.stroke;

    for (int i = -3; i < 10; i++) {
      final startX = size.width * 0.12 * i;
      canvas.drawLine(
        Offset(startX, 0),
        Offset(startX + size.height * 0.6, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CreateButton extends StatelessWidget {
  final VoidCallback? onPressed;
  const _CreateButton({this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: TextButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.add_circle_outline, size: 20),
        label: const Text(
          'Create New Estimate',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        style: TextButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

class _ViewAllButton extends StatelessWidget {
  final VoidCallback? onPressed;
  const _ViewAllButton({this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: BorderSide(color: primary, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: const Text(
          'View All Estimates',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}

class _StatsSection extends StatelessWidget {
  final bool loading;
  final int total;
  final int shared;
  final int drafts;

  const _StatsSection({
    required this.loading,
    required this.total,
    required this.shared,
    required this.drafts,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'Total Estimates',
                value: '$total',
                loading: loading,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                label: 'Shared',
                value: '$shared',
                loading: loading,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'Drafts',
                value: '$drafts',
                loading: loading,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(child: SizedBox()),
          ],
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final bool loading;

  const _StatCard({
    required this.label,
    required this.value,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: divider, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          loading
              ? Container(
                  width: 48,
                  height: 28,
                  decoration: BoxDecoration(
                    color: neutral,
                    borderRadius: BorderRadius.circular(6),
                  ),
                )
              : Text(
                  value,
                  style: const TextStyle(
                    color: textPrimary,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    height: 1,
                  ),
                ),
        ],
      ),
    );
  }
}

class _TotalValueCard extends StatelessWidget {
  final bool loading;
  final double totalValue;

  const _TotalValueCard({required this.totalValue, required this.loading});

  @override
  Widget build(BuildContext context) {
    final formatted = NumberFormat('#,##0', 'en_US').format(totalValue);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: primary,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: CustomPaint(painter: _WoodGrainPainter()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total Value',
                      style: TextStyle(
                        color: Color(0xFFB89A7A),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.account_balance_wallet_outlined,
                        color: tertiary,
                        size: 20,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                loading
                    ? Container(
                        width: 180,
                        height: 34,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      )
                    : Text(
                        'GH₵ $formatted',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                const SizedBox(height: 16),
                Row(
                  children: List.generate(
                    28,
                    (i) => Expanded(
                      child: Container(
                        height: i % 4 == 0 ? 10 : 6,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(
                            alpha: i % 4 == 0 ? 0.4 : 0.2,
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentEstimatesSection extends StatelessWidget {
  final bool loading;
  final List<Estimate> estimates;
  final VoidCallback? onSeeAllTap;

  const _RecentEstimatesSection({
    required this.loading,
    required this.estimates,
    this.onSeeAllTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Estimates',
              style: TextStyle(
                color: textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            GestureDetector(
              onTap: onSeeAllTap,
              child: Text(
                'See all',
                style: TextStyle(
                  color: secondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (loading)
          const Center(child: CircularProgressIndicator())
        else if (estimates.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'No estimates yet — create your first one!',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium!.copyWith(color: textSecondary),
              textAlign: TextAlign.center,
            ),
          )
        else
          ...estimates.map(
            (estimate) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _EstimateCard(estimate: estimate),
            ),
          ),
      ],
    );
  }
}

class _EstimateCard extends StatelessWidget {
  final Estimate estimate;

  const _EstimateCard({required this.estimate});

  Color get _statusColor {
    switch (estimate.status) {
      case EstimateStatus.finalised:
        return statusFinal;
      case EstimateStatus.shared:
        return statusShared;
      case EstimateStatus.draft:
        return statusDraft;
    }
  }

  Color get _statusBgColor {
    switch (estimate.status) {
      case EstimateStatus.finalised:
        return const Color(0xFFF0E8DE);
      case EstimateStatus.shared:
        return const Color(0xFFF5EAE0);
      case EstimateStatus.draft:
        return const Color(0xFFF2F2F2);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = estimate.date != null
        ? DateFormat('MMM d, y').format(estimate.date!)
        : 'No date';

    final amountStr =
        'GH₵ ${NumberFormat('#,##0', 'en_US').format(estimate.amount)}';

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: divider, width: 0.8),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      estimate.customerName ?? 'Unnamed customer',
                      style: const TextStyle(
                        color: textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      estimate.jobDescription ?? 'No description',
                      style: const TextStyle(
                        color: textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: _statusBgColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  estimate.statusLabel,
                  style: TextStyle(
                    color: _statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: divider.withValues(alpha: 0.6), height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                dateStr,
                style: const TextStyle(color: textSecondary, fontSize: 12),
              ),
              Text(
                amountStr,
                style: const TextStyle(
                  color: textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
