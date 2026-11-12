import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class RoomDeleteDialog extends StatefulWidget {
  final String roomName;
  const RoomDeleteDialog({super.key, required this.roomName});
  @override
  State<RoomDeleteDialog> createState() => _RoomDeleteDialogState();
}

class _RoomDeleteDialogState extends State<RoomDeleteDialog> {
  int _remaining = 8;
  late final Timer _timer;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() => _remaining--);
      if (_remaining == 0) timer.cancel();
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        icon: const Icon(CupertinoIcons.trash, color: AppTheme.errorColor),
        title: Text('Delete ${widget.roomName}?'),
        content: const Text(
            'This permanently removes this room and its beds. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.errorColor),
            onPressed:
                _remaining > 0 ? null : () => Navigator.pop(context, true),
            child:
                Text(_remaining > 0 ? 'Delete ($_remaining s)' : 'Delete room'),
          ),
        ],
      );
}
