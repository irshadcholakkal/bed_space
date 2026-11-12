import 'package:flutter_test/flutter_test.dart';
import 'package:bed_space/data/models/room_model.dart';
import 'property_financials_test.dart' as fixtures;

void main() {
  test(
      'Unavailable rooms persist status and suppress availability in their branches',
      () {
    final parent = RoomModel.fromJson(
        {...fixtures.spaces.first.toJson(), 'available': 'FALSE'});
    final child = fixtures.spaces[1];
    expect(parent.available, isFalse);
    expect(parent.isAvailable([parent, child]), isFalse);
    expect(child.isAvailable([parent, child]), isFalse);
    expect(RoomModel.fromJson(parent.toJson()).available, isFalse);
    final restored =
        RoomModel.fromJson({...parent.toJson(), 'available': 'TRUE'});
    expect(child.isAvailable([restored, child]), isTrue);
    final unavailableChild =
        RoomModel.fromJson({...child.toJson(), 'available': 'FALSE'});
    expect(unavailableChild.isAvailable([restored, unavailableChild]), isFalse);
  });
  test('Legacy rooms default to available', () {
    final legacy = fixtures.spaces.first.toJson()..remove('available');
    expect(RoomModel.fromJson(legacy).available, isTrue);
  });
}
