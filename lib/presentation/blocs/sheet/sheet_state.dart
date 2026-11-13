part of 'sheet_bloc.dart';

abstract class SheetState extends Equatable {
  const SheetState();

  @override
  List<Object> get props => [];
}

class SheetInitial extends SheetState {}

class SheetLoading extends SheetState {}

class SheetSetupProgress extends SheetLoading {
  final double progress;
  final String message;
  SheetSetupProgress(this.progress, this.message);
  @override
  List<Object> get props => [progress, message];
}

class SheetCreated extends SheetState {
  final String sheetId;

  const SheetCreated({required this.sheetId});

  @override
  List<Object> get props => [sheetId];
}

class SheetReset extends SheetState {}

class SheetSynced extends SheetState {}

class SheetError extends SheetState {
  final String message;

  const SheetError(this.message);

  @override
  List<Object> get props => [message];
}
