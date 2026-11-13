import 'package:flutter_test/flutter_test.dart';
import 'package:bed_space/data/models/bed_model.dart';
import 'package:bed_space/data/models/room_model.dart';
import 'package:bed_space/data/models/tenant_model.dart';
import 'package:bed_space/data/repositories/management_repository.dart';
import 'package:bed_space/presentation/blocs/management/management_bloc.dart';
import 'property_financials_test.dart' as fixtures;

class _Repo extends Fake implements ManagementRepository {
  final bool unavailable;
  final changes = <String, BedStatus>{};
  TenantModel? saved;
  _Repo(this.unavailable);
  @override
  Future<TenantModel?> getTenantById(String id) async =>
      fixtures.tenants.first.copyWith(bedId: 'old');
  @override
  Future<List<RoomModel>> getRooms({bool forceRefresh = false}) async => [
        RoomModel.fromJson({
          ...fixtures.spaces[2].toJson(),
          'available': unavailable ? 'FALSE' : 'TRUE'
        })
      ];
  @override
  Future<List<BedModel>> getBeds({bool forceRefresh = false}) async => [
        BedModel(
            bedId: 'new',
            roomId: 'sibling',
            bedType: BedType.lower,
            status: BedStatus.vacant)
      ];
  @override
  Future<List<TenantModel>> getTenants({bool forceRefresh = false}) async =>
      [fixtures.tenants.first];
  @override
  Future<void> updateBedStatus(String id, BedStatus status) async {
    changes[id] = status;
  }

  @override
  Future<void> updateTenant(TenantModel tenant) async {
    saved = tenant;
    changes['old'] = BedStatus.vacant;
    changes[tenant.bedId] = BedStatus.occupied;
  }
}

void main() {
  test('Transfer updates tenant location and both bed statuses', () async {
    final repo = _Repo(false);
    final bloc = ManagementBloc(repository: repo);
    final target = fixtures.tenants.first
        .copyWith(bedId: 'new', roomId: 'sibling', buildingId: 'b1');
    bloc.add(UpdateTenant(target));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(repo.saved?.tenantId, target.tenantId);
    expect(repo.saved?.roomId, 'sibling');
    expect(repo.changes, {'old': BedStatus.vacant, 'new': BedStatus.occupied});
    await bloc.close();
  });
  test('Transfer rejects unavailable destination before changing beds',
      () async {
    final repo = _Repo(true);
    final bloc = ManagementBloc(repository: repo);
    final failure =
        bloc.stream.firstWhere((s) => s is ManagementLoaded && s.error != null);
    bloc.add(UpdateTenant(fixtures.tenants.first
        .copyWith(bedId: 'new', roomId: 'sibling', buildingId: 'b1')));
    await failure;
    expect(repo.saved, isNull);
    expect(repo.changes, isEmpty);
    await bloc.close();
  });
}
