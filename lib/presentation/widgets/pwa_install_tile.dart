import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../data/services/pwa_install.dart';
import '../theme/app_theme.dart';

class PwaInstallTile extends StatefulWidget {
  const PwaInstallTile({super.key});
  @override
  State<PwaInstallTile> createState() => _PwaInstallTileState();
}

class _PwaInstallTileState extends State<PwaInstallTile> {
  bool _busy = false;
  bool _installed = isPwaInstalled();
  Future<void> _installApp() async {
    if (_busy || _installed) return;
    setState(() => _busy = true);
    final result = await installPwa();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _installed =
          result == 'installed' || result == 'accepted' || isPwaInstalled();
    });
    if (result == 'manual_ios' ||
        result == 'manual_browser' ||
        result == 'unavailable') {
      await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
                title: const Text('Install Bedspace'),
                content: Text(result == 'manual_ios'
                    ? 'Open this app in Safari, tap Share, then Add to Home Screen and Add.'
                    : 'Open your browser menu and choose Install app or Add to Home Screen. On desktop, look for the install icon in the address bar. If these options are missing, use a supported browser such as Chrome, Edge, or Safari.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Got it'))
                ],
              ));
    }
  }

  @override
  Widget build(BuildContext context) => Container(
      decoration: AppTheme.cardDecoration,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        leading: const Icon(CupertinoIcons.arrow_down_circle,
            color: AppTheme.primaryColor),
        title: Text(
            _installed ? 'Bedspace is installed' : 'Install Bedspace app',
            style: const TextStyle(
                fontWeight: FontWeight.w600, color: AppTheme.textColor)),
        subtitle: Text(_installed
            ? 'Open Bedspace from your home screen or app launcher.'
            : 'Add Bedspace to your home screen for quick access.'),
        trailing: _busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2))
            : Icon(
                _installed
                    ? CupertinoIcons.checkmark_circle
                    : CupertinoIcons.chevron_right,
                size: 20),
        onTap: _installed || _busy ? null : _installApp,
      ));
}
