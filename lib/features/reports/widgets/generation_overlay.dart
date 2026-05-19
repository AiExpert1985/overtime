import 'package:flutter/material.dart';

/// A single labeled phase shown during report generation.
class GenerationPhase {
  const GenerationPhase({
    required this.label,
    this.duration = const Duration(seconds: 4),
  });

  final String label;
  final Duration duration;
}

/// Full-screen overlay that animates through [phases] while [generationFuture]
/// runs in parallel. Calls [onComplete] when both finish, or [onError]
/// immediately if [generationFuture] throws — interrupting the animation.
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
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _rotationAnimation;

  int _currentPhaseIndex = 0;
  bool _cancelled = false;
  bool _phasesComplete = false;
  bool _generationComplete = false;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.88, end: 1.12).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _rotationAnimation = Tween<double>(begin: -0.06, end: 0.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

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
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final phase = widget.phases[_currentPhaseIndex];

    return AbsorbPointer(
      child: Container(
        color: Colors.black54,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _pulseController,
                builder: (_, child) => Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Transform.rotate(
                    angle: _rotationAnimation.value,
                    child: child,
                  ),
                ),
                child: const Icon(
                  Icons.auto_fix_high,
                  size: 100,
                  color: Color(0xFFFFD700),
                ),
              ),
              const SizedBox(height: 36),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.3),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOut,
                      ),
                    ),
                    child: child,
                  ),
                ),
                child: Text(
                  phase.label,
                  key: ValueKey(_currentPhaseIndex),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              _PhaseDots(
                count: widget.phases.length,
                current: _currentPhaseIndex,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhaseDots extends StatelessWidget {
  const _PhaseDots({required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (i) {
        final isActiveOrDone = i <= current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 6),
          width: isActiveOrDone ? 12 : 8,
          height: isActiveOrDone ? 12 : 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActiveOrDone
                ? const Color(0xFFFFD700)
                : Colors.white38,
          ),
        );
      }),
    );
  }
}
