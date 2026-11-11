import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../data/services/google_sheets_service.dart';
import '../../../data/repositories/sheet_repository.dart';
import '../../../data/services/saas_service.dart';

part 'sheet_event.dart';
part 'sheet_state.dart';

class SheetBloc extends Bloc<SheetEvent, SheetState> {
  final SheetRepository _sheetRepository;

  SheetBloc({
    required SheetRepository sheetRepository,
  })  : _sheetRepository = sheetRepository,
        super(SheetInitial()) {
    on<SheetCreateRequested>(_onSheetCreateRequested);
    on<SheetLinkRequested>(_onSheetLinkRequested);
    on<SheetResetRequested>(_onSheetResetRequested);
    on<SheetSyncRequested>(_onSheetSyncRequested);
  }

  Future<void> _onSheetLinkRequested(
    SheetLinkRequested event,
    Emitter<SheetState> emit,
  ) async {
    emit(SheetLoading());
    try {
      // Validate that it's not empty
      if (event.sheetId.trim().isEmpty) {
        throw Exception('Sheet ID cannot be empty');
      }

      await _sheetRepository.saveSheetId(event.sheetId.trim(), event.userEmail);
      emit(SheetCreated(sheetId: event.sheetId.trim()));
    } catch (e) {
      emit(SheetError(e.toString()));
    }
  }

  Future<void> _onSheetCreateRequested(
    SheetCreateRequested event,
    Emitter<SheetState> emit,
  ) async {
    emit(SheetLoading());
    try {
      final legacyName = SaasService.userId == null
          ? 'BedSpace_${event.userEmail}'
          : 'Bedspace_${SaasService.userId}';
      final sheetName = event.businessName.trim();
      if (sheetName.isEmpty) {
        throw StateError(
            'Enter your business name before creating a workspace.');
      }

      // 1. Try to find existing sheet first
      String? sheetId = await GoogleSheetsService.findSheetByTitle(
        event.accessToken,
        legacyName,
      );
      sheetId ??= await GoogleSheetsService.findSheetByTitle(
          event.accessToken, sheetName);

      // 2. If not found, create new
      sheetId ??= await GoogleSheetsService.createSheet(
        event.accessToken,
        sheetName,
      );

      final folderId = SaasService.userId == null
          ? null
          : await GoogleSheetsService.ensureDocumentFolder(
              event.accessToken, SaasService.userId!,
              businessName: sheetName);
      await _sheetRepository.saveSheetId(sheetId, event.userEmail,
          driveFolderId: folderId);

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
