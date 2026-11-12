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
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Container(
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: .07),
                      blurRadius: 20,
                      offset: const Offset(0, 5))
                ]),
            child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
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
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .48),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: .85))),
                        child: LayoutBuilder(builder: (context, constraints) {
                          final compact = constraints.maxWidth < 420;
                          return Material(
                              type: MaterialType.transparency,
                              child: Row(children: [
                                Container(
                                    width: 38,
                                    height: 38,
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
                                        size: 20)),
                                const SizedBox(width: 12),
                                Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      Text(
                                          isTrial
                                              ? 'Your one-month free trial is active'
                                              : 'Your membership is active',
                                          style: const TextStyle(
                                              color: AppTheme.textColor,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              height: 1.4)),
                                      const SizedBox(height: 3),
                                      Text(
                                          isTrial
                                              ? 'A little more room to get started.'
                                              : 'Your workspace, ready when you are.',
                                          style: const TextStyle(
                                              color:
                                                  AppTheme.secondaryTextColor,
                                              fontSize: 10,
                                              height: 1.4)),
                                    ])),
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
