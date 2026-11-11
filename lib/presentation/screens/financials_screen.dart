import 'package:flutter/material.dart';
import 'property_portfolio_screen.dart';

class FinancialsScreen extends StatelessWidget {
  final String? buildingId;
  final String? roomId;
  final String? period;
  const FinancialsScreen(
      {super.key, this.buildingId, this.roomId, this.period});
  @override
  Widget build(BuildContext context) => PropertyPortfolioScreen(
      financial: true, buildingId: buildingId, roomId: roomId, period: period);
}
