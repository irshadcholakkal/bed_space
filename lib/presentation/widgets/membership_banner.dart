import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class MembershipBanner extends StatelessWidget {
  final bool isTrial;
  final VoidCallback onPressed;
  const MembershipBanner(
      {super.key, required this.isTrial, required this.onPressed});

  @override
  Widget build(BuildContext context) => SafeArea(
      bottom: false,
      child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 2),
          child: Container(
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: .07),
                      blurRadius: 20,
                      offset: const Offset(0, 5))
                ]),
            child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(children: [
                  Positioned.fill(
                      child: DecoratedBox(
                          decoration: BoxDecoration(
                              gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                        AppTheme.primaryColor.withValues(alpha: .12),
                        const Color(0xfff8f3ff),
                        AppTheme.secondaryColor.withValues(alpha: .10)
                      ])))),
                  BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .48),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: .85))),
                        child: LayoutBuilder(builder: (context, constraints) {
                          final compact = constraints.maxWidth < 420;
                          return Material(
                              type: MaterialType.transparency,
                              child: Row(children: [
                                Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                        color:
                                            Colors.white.withValues(alpha: .7),
                                        borderRadius: BorderRadius.circular(12),
                                        border:
                                            Border.all(color: Colors.white)),
                                    child: Icon(
                                        isTrial
                                            ? CupertinoIcons.gift
                                            : CupertinoIcons.checkmark_seal,
                                        color: AppTheme.primaryColor,
                                        size: 16)),
                                const SizedBox(width: 10),
                                Expanded(
                                    child: Text(
                                        isTrial
                                            ? 'Your one-month free trial is active'
                                            : 'Your membership is active',
                                        style: const TextStyle(
                                            color: AppTheme.textColor,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            height: 1.35))),
                                const SizedBox(width: 8),
                                if (compact)
                                  IconButton(
                                      onPressed: onPressed,
                                      tooltip: 'Membership',
                                      icon: const Icon(
                                          CupertinoIcons.arrow_up_right,
                                          size: 18,
                                          color: AppTheme.textColor))
                                else
                                  TextButton.icon(
                                      onPressed: onPressed,
                                      style: TextButton.styleFrom(
                                          foregroundColor: AppTheme.textColor),
                                      icon: const Icon(
                                          CupertinoIcons.arrow_up_right,
                                          size: 15),
                                      label: const Text('Membership')),
                              ]));
                        }),
                      )),
                ])),
          )));
}
