part of 'estimates_cubit.dart';

sealed class EstimatesState extends Equatable {
  final List<Estimate> estimates;
  final String errorMessage;

  const EstimatesState({
    this.estimates = const [],
    this.errorMessage = '',
  });

  @override
  List<Object?> get props => [estimates, errorMessage];
}

final class EstimatesInitial extends EstimatesState {
  const EstimatesInitial();
}

final class EstimatesLoading extends EstimatesState {
  const EstimatesLoading();
}
final class EstimatesLoaded extends EstimatesState {
  const EstimatesLoaded({required super.estimates});
}

final class EstimatesError extends EstimatesState {
  const EstimatesError({required super.errorMessage});
}
