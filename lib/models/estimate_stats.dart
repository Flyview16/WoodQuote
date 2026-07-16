class EstimateStats {
  final int total;
  final int drafts;
  final int shared;
  final int finalised;
  final double totalValue;

  const EstimateStats({
    required this.total,
    required this.drafts,
    required this.shared,
    required this.finalised,
    required this.totalValue,
  });

  const EstimateStats.empty()
    : total = 0,
      drafts = 0,
      shared = 0,
      finalised = 0,
      totalValue = 0;
}
