import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/repositories/management_repository.dart';

Future<bool> refreshWorkspace(BuildContext context) async {
  try {
    await context.read<ManagementRepository>().triggerSync();
    return true;
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:
            Text('Could not refresh from Google Sheets. Showing saved data.'),
      ));
    }
    return false;
  }
}
