part of '../screens/landing_screen.dart';

class _FloatingGlyph extends StatelessWidget {
  final IconData icon;
  final double angle;
  const _FloatingGlyph(this.icon, {required this.angle});
  @override
  Widget build(BuildContext context) => Transform.rotate(
      angle: angle,
      child: Container(
          width: 62,
          height: 62,
          decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .035),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: .08))),
          child: Icon(icon,
              color: Colors.white.withValues(alpha: .35), size: 29)));
}

class _PlanCard extends StatelessWidget {
  final double width;
  final String title, price, period, description, button;
  final List<String> features;
  final VoidCallback onPressed;
  final bool highlighted;
  const _PlanCard(
      {required this.width,
      required this.title,
      required this.price,
      required this.period,
      required this.description,
      required this.features,
      required this.button,
      required this.onPressed,
      this.highlighted = false});
  @override
  Widget build(BuildContext context) => SizedBox(
      width: width,
      child: LandingHover(
          child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(26),
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                      color: highlighted ? const Color(0xff6c8288) : _border),
                  gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: highlighted
                          ? const [Color(0xff283439), Color(0xff111717)]
                          : const [Color(0xff181c1c), Color(0xff0c0f0f)])),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 24),
                    Text(price, style: _serif(45)),
                    const SizedBox(height: 8),
                    Text(period,
                        style: const TextStyle(color: _muted, fontSize: 12)),
                    const SizedBox(height: 18),
                    SizedBox(
                        height: 50,
                        child: Text(description,
                            style: const TextStyle(
                                color: _muted, fontSize: 12, height: 1.8))),
                    const Divider(height: 32, color: _border),
                    _tag('Included in your workspace'),
                    const SizedBox(height: 14),
                    for (final feature in features)
                      Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(CupertinoIcons.checkmark,
                                    size: 15, color: Color(0xffb5c3bf)),
                                const SizedBox(width: 9),
                                Expanded(
                                    child: Text(feature,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xffb6bdbc),
                                            height: 1.5)))
                              ])),
                    const SizedBox(height: 28),
                    SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                            onPressed: onPressed, child: Text(button))),
                  ]))));
}

class _ProductGraphic extends StatelessWidget {
  final int kind;
  final bool expanded;
  const _ProductGraphic({super.key, required this.kind, this.expanded = false});
  @override
  Widget build(BuildContext context) => LandingHover(
      child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(expanded ? 32 : 24),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _border),
              gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xff19272c),
                    [
                      const Color(0xff181b15),
                      const Color(0xff1b1724),
                      const Color(0xff10241e)
                    ][kind]
                  ])),
          child: Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                  color: const Color(0xe6101414),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _border),
                  boxShadow: const [
                    BoxShadow(color: Colors.black38, blurRadius: 30)
                  ]),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      for (var i = 0; i < 3; i++)
                        Container(
                            width: 5,
                            height: 5,
                            margin: const EdgeInsets.only(right: 5),
                            decoration: const BoxDecoration(
                                color: Color(0xff596262),
                                shape: BoxShape.circle)),
                      const Spacer(),
                      _tag('ILLUSTRATIVE DEMO')
                    ]),
                    const Divider(height: 32, color: _border),
                    Icon(
                        [
                          CupertinoIcons.arrow_branch,
                          CupertinoIcons.doc_text,
                          CupertinoIcons.folder
                        ][kind],
                        size: 28,
                        color: const Color(0xffb2c5c3)),
                    const SizedBox(height: 20),
                    Text(
                        [
                          'Your connected spaces',
                          'Rent at a glance',
                          'Your Google workspace'
                        ][kind],
                        style: _serif(25)),
                    const SizedBox(height: 22),
                    for (final row in [
                      [
                        ('Building A', '12 rooms'),
                        ('Room 101', '4 beds'),
                        ('Available', '2 beds')
                      ],
                      [
                        ('Rent recorded', 'AED 4,800'),
                        ('Invoice', 'Ready'),
                        ('Receipt', 'PDF')
                      ],
                      [
                        ('Accommodation records', 'Google Sheets'),
                        ('Document copies', 'Google Drive'),
                        ('Account details', 'Bedspace')
                      ],
                    ][kind])
                      Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 15),
                          decoration: BoxDecoration(
                              color: const Color(0xff1c2323),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: _border)),
                          child: Row(children: [
                            Icon(
                                [
                                  CupertinoIcons.square_grid_2x2,
                                  CupertinoIcons.money_dollar_circle,
                                  CupertinoIcons.cloud
                                ][kind],
                                size: 15,
                                color: const Color(0xff7f9c95)),
                            const SizedBox(width: 10),
                            Expanded(
                                child: Text(row.$1,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xffc0c8c5)))),
                            const SizedBox(width: 8),
                            Flexible(
                                child: Text(row.$2,
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(
                                        fontFamily: 'GeistMono',
                                        fontSize: 10,
                                        color: _muted)))
                          ])),
                    const SizedBox(height: 12),
                    const Row(children: [
                      Icon(CupertinoIcons.lock, size: 12, color: _muted),
                      SizedBox(width: 8),
                      Expanded(
                          child: Text('Your workspace. Your Google account.',
                              style: TextStyle(color: _muted, fontSize: 10)))
                    ]),
                  ]))));
}

class _GlowPainter extends CustomPainter {
  final double phase;
  _GlowPainter(this.phase);
  @override
  void paint(Canvas canvas, Size size) {
    final center =
        Offset(size.width * (.5 + math.sin(phase) * .18), size.height * .35);
    final paint = Paint()
      ..shader = const RadialGradient(colors: [
        Color(0x386691a3),
        Color(0x13bda96d),
        Colors.transparent
      ]).createShader(
          Rect.fromCircle(center: center, radius: size.width * .65));
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(_GlowPainter oldDelegate) => phase != oldDelegate.phase;
}
