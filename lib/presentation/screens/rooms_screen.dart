import 'package:flutter/material.dart';
import 'property_portfolio_screen.dart';

class RoomsScreen extends StatelessWidget {
  final String? buildingId;
  final String? roomId;
  final String? period;
  const RoomsScreen({super.key, this.buildingId, this.roomId, this.period});
  @override
  Widget build(BuildContext context) => PropertyPortfolioScreen(
      buildingId: buildingId, roomId: roomId, period: period);
}
