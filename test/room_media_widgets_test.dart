import 'dart:convert';
import 'package:bed_space/data/repositories/sheet_repository.dart';
import 'package:bed_space/presentation/blocs/management/management_bloc.dart';
import 'package:bed_space/presentation/screens/rooms_management_screen.dart';
import 'package:bed_space/presentation/widgets/room_sharing_actions.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'room_media_test.dart' show photo, video;
import 'subrooms_test.dart' show RoomRepository, SeededManagementBloc, room;

class _Picker extends FilePicker {
  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = false,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async {
    expect(withReadStream, isTrue);
    expect(withData, isFalse);
    return FilePickerResult([
      PlatformFile(
          name: 'Tour.mp4', size: 4, readStream: Stream.value([1, 2, 3, 4]))
    ]);
  }
}

void main() {
  const shareChannel = MethodChannel('dev.fluttercommunity.plus/share');
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SheetRepository().saveToken('token');
    await SheetRepository()
        .saveSheetId('sheet', 'customer@example.com', driveFolderId: 'folder');
  });

  test('switching workspace clears a previously cached Drive folder', () async {
    final repository = SheetRepository();
    expect(await repository.getDriveFolderId(), 'folder');
    await repository.saveSheetId('another-sheet', 'another@example.com');
    expect(await repository.getDriveFolderId(), isNull);
    await repository.saveSheetId('another-sheet', 'another@example.com',
        driveFolderId: 'new-folder');
    expect(await repository.getDriveFolderId(), 'new-folder');
    await repository.clearSheetId();
    expect(await repository.getDriveFolderId(), isNull);
  });

  testWidgets(
      'adding a subroom uploads selected video and saves its Drive reference',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    FilePicker.platform = _Picker();
    final repository = RoomRepository([room('parent', '101')]);
    final bloc = SeededManagementBloc(repository);
    addTearDown(bloc.close);
    var uploaded = false;
    final client = MockClient((request) async {
      if (request.method == 'GET') return http.Response('{"files":[]}', 200);
      if (request.method == 'POST') {
        return http.Response('', 200,
            headers: {'location': 'https://www.googleapis.com/upload/session'});
      }
      uploaded = true;
      return http.Response(
          jsonEncode({
            'id': 'video',
            'name': 'Tour.mp4',
            'mimeType': 'video/mp4',
            'size': '4'
          }),
          200);
    });
    await http.runWithClient(() async {
      await tester.pumpWidget(BlocProvider<ManagementBloc>.value(
          value: bloc,
          child: const MaterialApp(home: RoomsManagementScreen())));
      await tester.tap(find.byTooltip('Add Subroom'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.widgetWithText(TextField, 'Subroom Number / Name'), 'B');
      await tester.ensureVisible(find.text('Choose photos / videos'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose photos / videos'));
      await tester.pumpAndSettle();
      expect(find.text('Tour.mp4'), findsOneWidget);
      expect(uploaded, isFalse);
      await tester
          .ensureVisible(find.widgetWithText(ElevatedButton, 'Add Subroom'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Add Subroom'));
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pumpAndSettle();
      expect(uploaded, isTrue);
      expect(repository.addedRoom?.media.single.fileId, 'video');
      expect(repository.addedRoom?.roomNumber, 'B');
      expect(tester.takeException(), isNull);
    }, () => client);
    client.close();
  });

  testWidgets(
      'Room sharing preview includes details and only selected media links',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    MethodCall? shared;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(shareChannel,
        (call) async {
      shared = call;
      return 'com.whatsapp';
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(shareChannel, null));
    var changes = 0;
    final client = MockClient((request) async {
      expect(request.url.path, '/drive/v3/files/photo-id/permissions');
      if (request.method == 'GET') {
        return http.Response('{"permissions":[]}', 200);
      }
      changes++;
      return http.Response('{"id":"anyoneWithLink"}', 200);
    });
    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(
          home: Builder(
              builder: (context) => Scaffold(
                    body: FilledButton(
                        onPressed: () => showRoomShareDraft(context,
                            message: 'Room 101 · AED 650 per month',
                            media: [photo, video]),
                        child: const Text('Share room')),
                  ))));
      await tester.tap(find.text('Share room'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(video.name));
      await tester.tap(find.text('Review sharing message'));
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pumpAndSettle();
      final input = tester
          .widgetList<TextField>(find.byType(TextField))
          .singleWhere((field) => field.decoration?.labelText == 'Message');
      expect(input.controller!.text, contains('Room 101'));
      expect(input.controller!.text, contains(photo.viewUrl));
      expect(input.controller!.text, isNot(contains(video.viewUrl)));
      expect(changes, 1);
      expect(find.text('Recipient phone (optional)'), findsNothing);
      expect(find.text('Open WhatsApp'), findsNothing);
      await tester.tap(find.text('Share with apps'));
      await tester.pumpAndSettle();
      expect(shared?.method, 'share');
      final arguments = shared!.arguments as Map;
      expect(arguments['text'], input.controller!.text);
      expect(arguments['originWidth'], greaterThan(0));
      expect(arguments['originHeight'], greaterThan(0));
      expect(arguments.containsKey('phone'), isFalse);
      expect(tester.takeException(), isNull);
    }, () => client);
    client.close();
  });

  testWidgets(
      'unsupported native sharing offers copying and cancellation permits another attempt',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var unsupported = true;
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(shareChannel,
        (call) async {
      if (unsupported) throw PlatformException(code: 'unavailable');
      return 'dev.fluttercommunity.plus/share/dismissed';
    });
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String;
      }
      return null;
    });
    addTearDown(() {
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(shareChannel, null);
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                  body: FilledButton(
                      onPressed: () => showRoomShareDraft(context,
                          message: 'Room 101 · AED 650'),
                      child: const Text('Share room')),
                ))));
    await tester.tap(find.text('Share room'));
    await tester.pumpAndSettle();
    final message = tester.widget<TextField>(find.byType(TextField));
    await tester.enterText(find.byType(TextField),
        '${message.controller!.text}\nViewing available today');
    await tester.tap(find.text('Share with apps'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Sharing is unavailable here'), findsOneWidget);
    unsupported = false;
    await tester.tap(find.text('Share with apps'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Sharing is unavailable here'), findsNothing);
    await tester.tap(find.text('Copy details'));
    await tester.pumpAndSettle();
    expect(copied, contains('Viewing available today'));
    expect(tester.takeException(), isNull);
  });
}
