import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wood_quote/bloc/database_helper.dart';
import 'package:wood_quote/models/estimate.dart';

part 'estimates_state.dart';

class EstimatesCubit extends Cubit<EstimatesState> {
  EstimatesCubit({DatabaseHelper? databaseHelper})
    : _db = databaseHelper ?? DatabaseHelper.instance,
      super(EstimatesInitial());

  final DatabaseHelper _db;

  Future<void> loadEstimates() async {
    emit(EstimatesLoading());
    try {
      final estimates = await _db.getAllEstimates();
      emit(EstimatesLoaded(estimates: estimates));
    } catch (e) {
      emit(EstimatesError(errorMessage: 'Failed to load estimates: $e'));
    }
  }

  Future<Estimate?> getEstimateById(int id) async {
    return _db.getEstimate(id);
  }

  Future<void> refreshEstimates() async {
    try {
      final estimates = await _db.getAllEstimates();
      emit(EstimatesLoaded(estimates: estimates));
    } catch (e) {
      emit(EstimatesError(errorMessage: 'Failed to refresh estimates: $e'));
    }
  }

  Future<Estimate?> createEstimate(Estimate estimate) async {
    try {
      final savedEstimate = await _db.insertEstimate(estimate);

      final currentState = state;

      if (currentState is EstimatesLoaded) {
        emit(
          EstimatesLoaded(
            estimates: [savedEstimate, ...currentState.estimates],
          ),
        );
      } else {
        await loadEstimates();
      }

      return savedEstimate;
    } catch (e) {
      emit(EstimatesError(errorMessage: 'Failed to create estimate: $e'));
      return null;
    }
  }

  Future<Estimate?> updateEstimate(Estimate estimate) async {
    if (estimate.id == null) return null;

    try {
      await _db.updateEstimate(estimate);

      final updatedEstimate = await _db.getEstimate(estimate.id!);
      final currentState = state;

      if (updatedEstimate == null) {
        await loadEstimates();
        return null;
      }

      if (currentState is EstimatesLoaded) {
        emit(
          EstimatesLoaded(
            estimates: _replaceEstimate(
              currentState.estimates,
              updatedEstimate,
            ),
          ),
        );
      } else {
        await loadEstimates();
      }

      return updatedEstimate;
    } catch (e) {
      emit(EstimatesError(errorMessage: 'Failed to update estimate: $e'));
      return null;
    }
  }

  Future<void> deleteEstimate(int id) async {
    try {
      await _db.deleteEstimate(id);

      final currentState = state;

      if (currentState is EstimatesLoaded) {
        final updatedList = currentState.estimates
            .where((estimate) => estimate.id != id)
            .toList();

        emit(EstimatesLoaded(estimates: updatedList));
      } else {
        await loadEstimates();
      }
    } catch (error) {
      emit(EstimatesError(errorMessage: 'Failed to delete estimate: $error'));
    }
  }

  Future<void> finaliseEstimateWithPdf({
    required int estimateId,
    required String pdfPath,
  }) async {
    try {
      await _db.finaliseEstimateWithPdf(
        estimateId: estimateId,
        pdfPath: pdfPath,
      );

      await _refreshSingleEstimateInState(estimateId);
    } catch (e) {
      emit(EstimatesError(errorMessage: 'Failed to finalise estimate: $e'));
    }
  }

  Future<void> markEstimateAsShared({required int estimateId}) async {
    try {
      await _db.markEstimateAsShared(estimateId: estimateId);

      await _refreshSingleEstimateInState(estimateId);
    } catch (e) {
      emit(
        EstimatesError(errorMessage: 'Failed to mark estimate as shared: $e'),
      );
    }
  }

  Future<void> updateEstimatePdfPath({
    required int estimateId,
    required String pdfPath,
  }) async {
    try {
      await _db.updateEstimatePdfPath(estimateId: estimateId, pdfPath: pdfPath);

      await _refreshSingleEstimateInState(estimateId);
    } catch (e) {
      emit(
        EstimatesError(errorMessage: 'Failed to update estimate PDF path: $e'),
      );
    }
  }

  Future<void> clearEstimatePdf({required int estimateId}) async {
    try {
      await _db.clearEstimatePdf(estimateId: estimateId);

      await _refreshSingleEstimateInState(estimateId);
    } catch (e) {
      emit(EstimatesError(errorMessage: 'Failed to clear estimate PDF: $e'));
    }
  }

  Future<void> _refreshSingleEstimateInState(int estimateId) async {
    final updatedEstimate = await _db.getEstimate(estimateId);
    final currentState = state;

    if (updatedEstimate == null) {
      await loadEstimates();
      return;
    }

    if (currentState is EstimatesLoaded) {
      emit(
        EstimatesLoaded(
          estimates: _replaceEstimate(currentState.estimates, updatedEstimate),
        ),
      );
    } else {
      await loadEstimates();
    }
  }

  List<Estimate> _replaceEstimate(
    List<Estimate> estimates,
    Estimate updatedEstimate,
  ) {
    return estimates.map((estimate) {
      return estimate.id == updatedEstimate.id ? updatedEstimate : estimate;
    }).toList();
  }
}
