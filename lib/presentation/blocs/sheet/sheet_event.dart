part of 'sheet_bloc.dart';

abstract class SheetEvent extends Equatable {
  const SheetEvent();

  @override
  List<Object> get props => [];
}

class SheetCreateRequested extends SheetEvent {
  final String accessToken;
  final String userEmail;

  const SheetCreateRequested({
    required this.accessToken,
    required this.userEmail,
  });

  @override
  List<Object> get props => [accessToken, userEmail];
}

class SheetResetRequested extends SheetEvent {
  const SheetResetRequested();
}

class SheetSyncRequested extends SheetEvent {
  const SheetSyncRequested();
}

class SheetLinkRequested extends SheetEvent {
  final String sheetId;
  final String userEmail;

  const SheetLinkRequested({
    required this.sheetId,
    required this.userEmail,
  });

  @override
  List<Object> get props => [sheetId, userEmail];
}
