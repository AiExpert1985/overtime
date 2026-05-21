import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class GenerationPhase {
  const GenerationPhase({
    required this.label,
    this.duration = const Duration(seconds: 3),
  });

  final String label;
  final Duration duration;
}

class GenerationOverlay extends StatefulWidget {
  const GenerationOverlay({
    super.key,
    required this.phases,
    required this.generationFuture,
    required this.onComplete,
    required this.onError,
  });

  final List<GenerationPhase> phases;
  final Future<void> generationFuture;
  final VoidCallback onComplete;
  final void Function(Object error) onError;

  @override
  State<GenerationOverlay> createState() => _GenerationOverlayState();
}

class _GenerationOverlayState extends State<GenerationOverlay>
    with TickerProviderStateMixin {
  int _currentPhaseIndex = 0;
  bool _cancelled = false;
  bool _phasesComplete = false;
  bool _generationComplete = false;

  late final AnimationController _dotController;

  @override
  void initState() {
    super.initState();
    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
    _startPhaseSequence();
    _awaitGeneration();
  }

  Future<void> _startPhaseSequence() async {
    for (var i = 0; i < widget.phases.length; i++) {
      if (_cancelled || !mounted) return;
      setState(() => _currentPhaseIndex = i);
      await Future.delayed(widget.phases[i].duration);
    }
    if (_cancelled || !mounted) return;
    _phasesComplete = true;
    _checkBothComplete();
  }

  void _awaitGeneration() {
    () async {
      try {
        await widget.generationFuture;
        if (_cancelled || !mounted) return;
        _generationComplete = true;
        _checkBothComplete();
      } catch (e) {
        if (_cancelled || !mounted) return;
        _cancelled = true;
        widget.onError(e);
      }
    }();
  }

  void _checkBothComplete() {
    if (_phasesComplete && _generationComplete && mounted) {
      widget.onComplete();
    }
  }

  @override
  void dispose() {
    _cancelled = true;
    _dotController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AbsorbPointer(
      child: Stack(
        children: [
          BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
            child: Container(
              color: Theme.of(context)
                  .colorScheme
                  .surface
                  .withValues(alpha: 0.3),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildProcessingOrb(context),
                const SizedBox(height: 64),
                _buildPhaseLog(context),
              ],
            ),
          ),
        ],
      ).animate().fade(duration: 500.ms, curve: Curves.easeOut),
    );
  }

  Widget _buildProcessingOrb(BuildContext context) {
    return SizedBox(
      width: 240,
      height: 240,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer slow ring
          Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.1),
                width: 1,
              ),
            ),
          )
              .animate(onPlay: (c) => c.repeat())
              .rotate(duration: 12.seconds, curve: Curves.linear),

          // Middle counter-rotating ring
          Container(
            width: 190,
            height: 190,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.2),
                width: 6,
              ),
            ),
          )
              .animate(onPlay: (c) => c.repeat())
              .rotate(begin: 1, end: 0, duration: 8.seconds, curve: Curves.linear),

          // Pulsing accent ring
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Theme.of(context)
                    .colorScheme
                    .secondary
                    .withValues(alpha: 0.5),
                width: 2,
              ),
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scale(
                begin: const Offset(0.9, 0.9),
                end: const Offset(1.1, 1.1),
                duration: 2.seconds,
                curve: Curves.easeInOutSine,
              ),

          // Glow halo
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.6),
                  blurRadius: 40,
                  spreadRadius: 10,
                ),
              ],
            ),
          ),

          // Core orb with rotating sync icon
          ClipOval(
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.7),
                  ],
                ),
              ),
              child: Center(
                child: Icon(
                  Icons.sync_rounded,
                  size: 52,
                  color: Colors.white,
                )
                    .animate(onPlay: (c) => c.repeat())
                    .rotate(duration: 1800.ms, curve: Curves.linear),
              ),
            )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scale(
                  begin: const Offset(0.95, 0.95),
                  end: const Offset(1.05, 1.05),
                  duration: 1.seconds,
                  curve: Curves.easeInOut,
                )
                .shimmer(
                  duration: 2.seconds,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhaseLog(BuildContext context) {
    return Container(
      width: 580,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 40),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color:
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: List.generate(widget.phases.length, (index) {
          final isCompleted = index < _currentPhaseIndex;
          final isActive = index == _currentPhaseIndex;
          final phase = widget.phases[index];

          return AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutCubic,
            margin: EdgeInsets.only(bottom: isActive ? 24 : 16),
            child: Row(
              children: [
                SizedBox(
                  width: 36,
                  child: isCompleted
                      ? const Icon(Icons.check, color: Color(0xFF22C55E), size: 28)
                          .animate()
                          .scale(curve: Curves.elasticOut, duration: 600.ms)
                      : isActive
                          ? _BouncingDots(controller: _dotController)
                          : Icon(
                              Icons.radio_button_unchecked,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.15),
                              size: 22,
                            ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOut,
                    style: TextStyle(
                      fontFamily:
                          Theme.of(context).textTheme.bodyLarge?.fontFamily,
                      fontSize: isActive ? 24 : 18,
                      fontWeight:
                          isActive ? FontWeight.bold : FontWeight.w600,
                      color: isCompleted
                          ? Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.4)
                          : isActive
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.2),
                    ),
                    child: Text(phase.label),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _BouncingDots extends StatelessWidget {
  const _BouncingDots({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        final offset = i / 3.0;
        return AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final t = ((controller.value + offset) % 1.0);
            final dy = t < 0.5
                ? -8.0 * (t * 2)
                : -8.0 * (1.0 - (t - 0.5) * 2);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Transform.translate(
                offset: Offset(0, dy),
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}
