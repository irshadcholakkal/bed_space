import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Framer-style one-shot viewport reveal. Reduced-motion keeps content visible.
class LandingReveal extends StatefulWidget {
  final ScrollController scroll;
  final Widget child;
  final int delay;
  const LandingReveal(
      {super.key, required this.scroll, required this.child, this.delay = 0});
  @override
  State<LandingReveal> createState() => _LandingRevealState();
}

class _LandingRevealState extends State<LandingReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
      vsync: this, duration: Duration(milliseconds: 700 + widget.delay));
  bool _shown = false;
  @override
  void initState() {
    super.initState();
    widget.scroll.addListener(_check);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _shown = true;
      _animation.value = 1;
    }
  }

  void _check() {
    if (!mounted || _shown) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    if (box.localToGlobal(Offset.zero).dy <
        MediaQuery.sizeOf(context).height * .96) {
      _shown = true;
      _animation.forward();
    }
  }

  @override
  void dispose() {
    widget.scroll.removeListener(_check);
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: _animation,
      child: widget.child,
      builder: (context, child) {
        final value = Curves.easeOutCubic.transform(_animation.value);
        return Opacity(
            opacity: value,
            child: Transform.translate(
                offset: Offset(0, 24 * (1 - value)),
                child:
                    Transform.scale(scale: .95 + .05 * value, child: child)));
      });
}

class LandingWordEntrance extends StatefulWidget {
  final String text;
  final TextStyle style;
  const LandingWordEntrance(
      {super.key, required this.text, required this.style});
  @override
  State<LandingWordEntrance> createState() => _LandingWordEntranceState();
}

class _LandingWordEntranceState extends State<LandingWordEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1500));
  @override
  void initState() {
    super.initState();
    _animation.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) _animation.value = 1;
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final words = widget.text.split(' ');
    return Semantics(
        header: true,
        label: widget.text,
        excludeSemantics: true,
        child: AnimatedBuilder(
            animation: _animation,
            builder: (context, _) => Wrap(
                    alignment: WrapAlignment.center,
                    spacing: widget.style.fontSize! * .22,
                    runSpacing: 0,
                    children: [
                      for (var i = 0; i < words.length; i++)
                        Builder(builder: (_) {
                          final value = Curves.easeOutCubic.transform(
                              ((_animation.value -
                                          (words.length > 1
                                              ? i / (words.length - 1) * .35
                                              : 0)) /
                                      .65)
                                  .clamp(0.0, 1.0));
                          return Opacity(
                              opacity: value,
                              child: Transform.translate(
                                  offset: Offset(0, (1 - value) * 12),
                                  child: ImageFiltered(
                                      imageFilter: ui.ImageFilter.blur(
                                          sigmaX: (1 - value) * 9,
                                          sigmaY: (1 - value) * 9),
                                      child: Text(words[i],
                                          style: widget.style))));
                        }),
                    ])));
  }
}

class LandingHover extends StatefulWidget {
  final Widget child;
  final BorderRadius borderRadius;
  const LandingHover(
      {super.key,
      required this.child,
      this.borderRadius = const BorderRadius.all(Radius.circular(20))});
  @override
  State<LandingHover> createState() => _LandingHoverState();
}

class _LandingHoverState extends State<LandingHover> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 240),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(0, _hover ? -5 : 0, 0),
          decoration:
              BoxDecoration(borderRadius: widget.borderRadius, boxShadow: [
            BoxShadow(
                color:
                    const Color(0xff7ea5b2).withValues(alpha: _hover ? .11 : 0),
                blurRadius: 36,
                spreadRadius: 2)
          ]),
          child: widget.child));
}

class LandingScrollWords extends StatelessWidget {
  final ScrollController scroll;
  final String text;
  const LandingScrollWords(
      {super.key, required this.scroll, required this.text});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: scroll,
      builder: (context, _) {
        final box = context.findRenderObject();
        final height = MediaQuery.sizeOf(context).height;
        final top = box is RenderBox && box.hasSize
            ? box.localToGlobal(Offset.zero).dy
            : height;
        final progress = MediaQuery.disableAnimationsOf(context)
            ? 1.0
            : ((height * .9 - top) / (height * .7)).clamp(0.0, 1.0);
        final words = text.split(' ');
        return Text.rich(
            TextSpan(children: [
              for (var i = 0; i < words.length; i++)
                TextSpan(
                    text: '${words[i]} ',
                    style: TextStyle(
                        color: Color.lerp(
                            const Color(0xff404444),
                            const Color(0xfff5f5f5),
                            MediaQuery.disableAnimationsOf(context)
                                ? 1.0
                                : ((progress * 1.2 - i / words.length) * 5)
                                    .clamp(0.0, 1.0))))
            ]),
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: 'HedvigLetters',
                fontSize: MediaQuery.sizeOf(context).width > 750 ? 43 : 28,
                height: 1.4,
                letterSpacing: -.8));
      });
}
