import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../data/services/google_sheets_service.dart';
import '../../../data/repositories/sheet_repository.dart';

part 'sheet_event.dart';
part 'sheet_state.dart';

class SheetBloc extends Bloc<SheetEvent, SheetState> {
  final SheetRepository _sheetRepository;

  SheetBloc({
    required SheetRepository sheetRepository,
  })  : _sheetRepository = sheetRepository,
        super(SheetInitial()) {
    on<SheetCreateRequested>(_onSheetCreateRequested);
    on<SheetResetRequested>(_onSheetResetRequested);
    on<SheetSyncRequested>(_onSheetSyncRequested);
  }

  Future<void> _onSheetCreateRequested(
    SheetCreateRequested event,
    Emitter<SheetState> emit,
  ) async {
    emit(SheetLoading());
    try {
      final sheetName = 'BedSpace_${event.userEmail}';
      final sheetId = await GoogleSheetsService.createSheet(
        event.accessToken,
        sheetName,
      );

      await _sheetRepository.saveSheetId(sheetId, event.userEmail);

      emit(SheetCreated(sheetId: sheetId));
    } catch (e) {
      emit(SheetError(e.toString()));
    }
  }

  Future<void> _onSheetResetRequested(
    SheetResetRequested event,
    Emitter<SheetState> emit,
  ) async {
    emit(SheetLoading());
    try {
      await _sheetRepository.clearSheetId();
      emit(SheetReset());
    } catch (e) {
      emit(SheetError(e.toString()));
    }
  }

  Future<void> _onSheetSyncRequested(
    SheetSyncRequested event,
    Emitter<SheetState> emit,
  ) async {
    emit(SheetLoading());
    try {
      // In a real app, you might want to verify the sheet exists
      // For now, we'll just emit success
      emit(SheetSynced());
    } catch (e) {
      emit(SheetError(e.toString()));
    }
  }
}

