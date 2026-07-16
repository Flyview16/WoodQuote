import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:wood_quote/bloc/cubit/estimates_cubit.dart';
import 'package:wood_quote/models/estimate.dart';
import 'package:wood_quote/screens/create_screen.dart';
import 'package:wood_quote/screens/estimate_preview_screen.dart';
import 'package:wood_quote/screens/shared_widgets/custom_appbar.dart';
import 'package:wood_quote/utils/colors.dart';

enum _SortOrder { newestFirst, oldestFirst }

enum _Filter { all, draft, shared, finalised }

class EstimatesScreen extends StatefulWidget {
  const EstimatesScreen({super.key});

  @override
  State<EstimatesScreen> createState() => _EstimatesScreenState();
}

class _EstimatesScreenState extends State<EstimatesScreen> {
  final _searchController = TextEditingController();

  _Filter _filter = _Filter.all;
  _SortOrder _sortOrder = _SortOrder.newestFirst;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshEstimates() {
    return context.read<EstimatesCubit>().loadEstimates();
  }

  List<Estimate> _applyFilters(List<Estimate> estimates) {
    List<Estimate> list = List<Estimate>.from(estimates);

    if (_filter != _Filter.all) {
      final targetStatus = switch (_filter) {
        _Filter.draft => EstimateStatus.draft,
        _Filter.shared => EstimateStatus.shared,
        _Filter.finalised => EstimateStatus.finalised,
        _Filter.all => EstimateStatus.draft,
      };

      list = list.where((estimate) => estimate.status == targetStatus).toList();
    }

    if (_searchQuery.isNotEmpty) {
      list = list.where((estimate) {
        final name = estimate.customerName?.toLowerCase() ?? '';
        final description = estimate.jobDescription?.toLowerCase() ?? '';

        return name.contains(_searchQuery) ||
            description.contains(_searchQuery);
      }).toList();
    }

    list.sort((a, b) {
      final dateA = a.date ?? DateTime.fromMillisecondsSinceEpoch(0);
      final dateB = b.date ?? DateTime.fromMillisecondsSinceEpoch(0);

      final result = _sortOrder == _SortOrder.newestFirst
          ? dateB.compareTo(dateA)
          : dateA.compareTo(dateB);

      if (result != 0) return result;

      final idA = a.id ?? 0;
      final idB = b.id ?? 0;

      return _sortOrder == _SortOrder.newestFirst
          ? idB.compareTo(idA)
          : idA.compareTo(idB);
    });

    return list;
  }

  void _toggleSort() {
    setState(() {
      _sortOrder = _sortOrder == _SortOrder.newestFirst
          ? _SortOrder.oldestFirst
          : _SortOrder.newestFirst;
    });
  }

  void _changeFilter(_Filter filter) {
    setState(() {
      _filter = filter;
    });
  }

  Future<void> _openDraftEditor(Estimate estimate) async {
    if (estimate.id == null) return;

    final fullEstimate = await context.read<EstimatesCubit>().getEstimateById(
      estimate.id!,
    );

    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateScreen(estimate: fullEstimate ?? estimate),
      ),
    );
  }

  void _handleCardTap(Estimate estimate) {
    if (estimate.status == EstimateStatus.draft) {
      _openDraftEditor(estimate);
      return;
    }

    _viewEstimate(estimate);
  }

  Future<void> _viewEstimate(Estimate estimate) async {
    if (estimate.id == null) return;

    final fullEstimate = await context.read<EstimatesCubit>().getEstimateById(
      estimate.id!,
    );

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            EstimatePreviewScreen(estimate: fullEstimate ?? estimate),
      ),
    );
  }

  Future<void> _shareEstimate(Estimate estimate) async {
    await _viewEstimate(estimate);
  }

  Future<void> _confirmDeleteEstimate(Estimate estimate) async {
    final estimateId = estimate.id;
    if (estimateId == null) return;

    final clientName = estimate.customerName?.trim().isNotEmpty == true
        ? estimate.customerName!.trim()
        : 'this estimate';

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete estimate?'),
          content: Text(
            'Are you sure you want to delete estimate for $clientName? This action cannot be undone.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                'Cancel',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),

              child: Text(
                'Delete',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) return;
    if (!mounted) return;

    await context.read<EstimatesCubit>().deleteEstimate(estimateId);

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Estimate deleted.')));
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: neutral,
      body: BlocBuilder<EstimatesCubit, EstimatesState>(
        builder: (context, state) {
          final bool loading =
              state is EstimatesInitial || state is EstimatesLoading;

          final bool error = state is EstimatesError;

          final List<Estimate> estimates = state is EstimatesLoaded
              ? state.estimates
              : <Estimate>[];

          final List<Estimate> filteredEstimates = _applyFilters(estimates);

          return RefreshIndicator(
            color: primary,
            onRefresh: _refreshEstimates,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                CustomAppBar(),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      Text(
                        'All Estimates',
                        style: tt.displaySmall!.copyWith(
                          color: textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Manage and track your carpentry quotes.',
                        style: tt.bodyMedium!.copyWith(
                          color: textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 20),

                      _SearchBar(controller: _searchController),
                      const SizedBox(height: 16),

                      _FilterRow(
                        selected: _filter,
                        sortOrder: _sortOrder,
                        onFilterChanged: _changeFilter,
                        onSortToggle: _toggleSort,
                      ),
                      const SizedBox(height: 16),

                      if (loading)
                        const _LoadingState()
                      else if (error)
                        _ErrorState(
                          message: state.errorMessage,
                          onRetry: _refreshEstimates,
                        )
                      else if (filteredEstimates.isEmpty)
                        _EmptyState(
                          hasSearch: _searchQuery.isNotEmpty,
                          hasFilter: _filter != _Filter.all,
                        )
                      else
                        ...filteredEstimates.map(
                          (estimate) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _EstimateCard(
                              estimate: estimate,
                              onTap: () => _handleCardTap(estimate),
                              onEdit: () => _openDraftEditor(estimate),
                              onShare: () => _shareEstimate(estimate),
                              onView: () => _viewEstimate(estimate),
                              onDelete: () => _confirmDeleteEstimate(estimate),
                            ),
                          ),
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
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;

  const _SearchBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: divider, width: 0.8),
      ),
      child: TextField(
        controller: controller,
        style: Theme.of(
          context,
        ).textTheme.bodyLarge!.copyWith(color: textPrimary),
        decoration: InputDecoration(
          hintText: 'Search by client or description',
          hintStyle: Theme.of(context).textTheme.bodyMedium!.copyWith(
            color: textSecondary.withValues(alpha: 0.65),
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: textSecondary,
            size: 22,
          ),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, child) {
              if (value.text.isEmpty) {
                return const Icon(
                  Icons.filter_list_rounded,
                  color: textSecondary,
                  size: 20,
                );
              }

              return IconButton(
                onPressed: controller.clear,
                icon: const Icon(
                  Icons.close_rounded,
                  color: textSecondary,
                  size: 20,
                ),
              );
            },
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  final _Filter selected;
  final _SortOrder sortOrder;
  final ValueChanged<_Filter> onFilterChanged;
  final VoidCallback onSortToggle;

  const _FilterRow({
    required this.selected,
    required this.sortOrder,
    required this.onFilterChanged,
    required this.onSortToggle,
  });

  String _filterLabel(_Filter filter) {
    return switch (filter) {
      _Filter.all => 'All',
      _Filter.draft => 'Draft',
      _Filter.shared => 'Shared',
      _Filter.finalised => 'Final',
    };
  }

  String get _sortLabel {
    return switch (sortOrder) {
      _SortOrder.newestFirst => 'Newest first',
      _SortOrder.oldestFirst => 'Oldest first',
    };
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _Filter.values.map((filter) {
                final isSelected = filter == selected;

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => onFilterChanged(filter),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected ? primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _filterLabel(filter),
                        style: tt.bodyMedium!.copyWith(
                          color: isSelected ? Colors.white : textPrimary,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: onSortToggle,
          child: Row(
            children: [
              const Icon(Icons.sort_rounded, size: 16, color: textSecondary),
              const SizedBox(width: 4),
              Text(
                _sortLabel,
                style: tt.bodySmall!.copyWith(
                  color: textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EstimateCard extends StatelessWidget {
  final Estimate estimate;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onShare;
  final VoidCallback onView;
  final VoidCallback onDelete;

  const _EstimateCard({
    required this.estimate,
    required this.onTap,
    required this.onEdit,
    required this.onShare,
    required this.onView,
    required this.onDelete,
  });

  Color get _statusColor {
    return switch (estimate.status) {
      EstimateStatus.finalised => const Color(0xFF1F6B2D),
      EstimateStatus.shared => const Color(0xFF245CA8),
      EstimateStatus.draft => const Color(0xFF7A4B00),
    };
  }

  Color get _statusBgColor {
    return switch (estimate.status) {
      EstimateStatus.finalised => const Color(0xFFE5F5E8),
      EstimateStatus.shared => const Color(0xFFE6F0FF),
      EstimateStatus.draft => const Color(0xFFFFE9B8),
    };
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    final dateStr = estimate.date != null
        ? DateFormat('MMM d, y').format(estimate.date!)
        : 'No date';

    final amountStr = NumberFormat(
      'GH₵ #,##0.00',
      'en_US',
    ).format(estimate.amount);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: divider, width: 0.8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: name + status badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      estimate.customerName ?? 'Unnamed client',
                      style: tt.bodyLarge!.copyWith(
                        color: textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: _statusBgColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      estimate.statusLabel,
                      style: tt.labelSmall!.copyWith(
                        color: _statusColor,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 4),

              Text(
                dateStr,
                style: tt.bodySmall!.copyWith(
                  color: const Color(0xFF6D6258),
                  fontWeight: FontWeight.w600,
                ),
              ),

              if (estimate.jobDescription != null &&
                  estimate.jobDescription!.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  estimate.jobDescription!,
                  style: tt.bodyMedium!.copyWith(
                    color: const Color(0xFF3D332B),
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              const SizedBox(height: 14),
              Divider(color: divider.withValues(alpha: 0.7), height: 1),
              const SizedBox(height: 12),

              Row(
                children: [
                  Text(
                    amountStr,
                    style: tt.bodyLarge!.copyWith(
                      color: textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  _buildActions(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActions() {
    return switch (estimate.status) {
      EstimateStatus.draft => Row(
        children: [
          _ActionIcon(Icons.edit_outlined, onTap: onEdit),
          const SizedBox(width: 16),
          _ActionIcon(
            Icons.delete_outline_rounded,
            onTap: onDelete,
            color: Colors.red,
          ),
        ],
      ),

      EstimateStatus.finalised => Row(
        children: [
          _ActionIcon(Icons.remove_red_eye_outlined, onTap: onView),
          const SizedBox(width: 16),
          _ActionIcon(Icons.share_outlined, onTap: onShare),
          const SizedBox(width: 16),
          _ActionIcon(
            Icons.delete_outline_rounded,
            onTap: onDelete,
            color: Colors.red,
          ),
        ],
      ),

      EstimateStatus.shared => Row(
        children: [
          _ActionIcon(Icons.remove_red_eye_outlined, onTap: onView),
          const SizedBox(width: 16),
          _ActionIcon(Icons.share_outlined, onTap: onShare),
          const SizedBox(width: 16),
          _ActionIcon(
            Icons.delete_outline_rounded,
            onTap: onDelete,
            color: Colors.red,
          ),
        ],
      ),
    };
  }
}

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  const _ActionIcon(this.icon, {required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, size: 22, color: color ?? primary),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 60),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Column(
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 56,
            color: textSecondary.withValues(alpha: 0.45),
          ),
          const SizedBox(height: 16),
          Text(
            'Could not load estimates',
            style: tt.titleMedium!.copyWith(color: textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: tt.bodyMedium!.copyWith(color: textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          TextButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasSearch;
  final bool hasFilter;

  const _EmptyState({required this.hasSearch, required this.hasFilter});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    final title = hasSearch || hasFilter
        ? 'No results found'
        : 'No estimates yet';

    final subtitle = hasSearch || hasFilter
        ? 'Try changing your search term or selected filter.'
        : 'Tap the + button to create your first estimate.';

    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Column(
        children: [
          Icon(
            hasSearch || hasFilter
                ? Icons.search_off_rounded
                : Icons.description_outlined,
            size: 56,
            color: textSecondary.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(title, style: tt.titleMedium!.copyWith(color: textPrimary)),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: tt.bodyMedium!.copyWith(color: textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
