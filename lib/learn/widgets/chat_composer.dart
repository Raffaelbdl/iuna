import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../theme/iuna_theme.dart';
import '../../widgets/snack.dart';
import '../photo/photo.dart';
import '../photo/photo_picker.dart';
import '../voice/dictation.dart';
import 'photo_attachment.dart';
import 'waveform.dart';

/// The message field and its send button (stop, mid-reply) — or, while
/// the field is empty, a mic to hold while speaking. Public because the
/// Learn hub's chat bar is one too.
class ChatComposer extends StatefulWidget {
  const ChatComposer({
    super.key,
    required this.controller,
    required this.hint,
    required this.onSend,
    this.enabled = true,
    this.busy = false,
    this.onStop,
    this.recorder,
    this.onVoice,
    this.picker,
    this.photo,
    this.onPhoto,
  });

  final TextEditingController controller;
  final String hint;
  final VoidCallback onSend;
  final bool enabled;
  final bool busy;
  final VoidCallback? onStop;

  /// With [onVoice]: the mic shows while the field is empty.
  final VoiceRecorder Function()? recorder;
  final ValueChanged<VoiceClip>? onVoice;

  /// With [onPhoto]: a paperclip that attaches one photo to the next
  /// message. The photo itself is the parent's, like the text is.
  final PhotoPicker? picker;
  final Photo? photo;
  final ValueChanged<Photo?>? onPhoto;

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

enum _Hold { idle, starting, recording, locked, stopping }

class _ChatComposerState extends State<ChatComposer> with SingleTickerProviderStateMixin {
  /// Shorter than this is a tap, not speech.
  static const _minLength = Duration(milliseconds: 500);

  /// How far left the finger goes before letting go cancels.
  static const _cancelDistance = 96.0;

  /// How far up the finger goes before the recording keeps itself.
  static const _lockDistance = 64.0;

  /// Times the hold without rebuilding anything: the recording bar
  /// redraws only the clock each second and the waveform per level.
  late final Ticker _ticker;
  Duration _elapsed = Duration.zero;
  final _seconds = ValueNotifier<int>(0);
  final _levels = _Levels();
  VoiceRecorder? _recorder;
  StreamSubscription<double>? _levelsSub;
  _Hold _hold = _Hold.idle;
  double _pressX = 0;
  double _pressY = 0;

  /// 0..1 of the way up to the lock; only the lock pill watches it.
  final _lift = ValueNotifier<double>(0);
  bool _cancelArmed = false;
  String? _nudge;
  Timer? _nudgeTimer;

  bool get _canDictate => widget.recorder != null && widget.onVoice != null;

  bool get _canAttach => widget.picker != null && widget.onPhoto != null;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      _elapsed = elapsed;
      _seconds.value = elapsed.inSeconds;
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    _nudgeTimer?.cancel();
    _levelsSub?.cancel();
    _seconds.dispose();
    _levels.dispose();
    _lift.dispose();
    final recorder = _recorder;
    if (recorder != null) {
      final recording = _hold == _Hold.recording || _hold == _Hold.locked;
      unawaited(() async {
        if (recording) await recorder.cancel();
        await recorder.dispose();
      }());
    }
    super.dispose();
  }

  Future<void> _press(PointerDownEvent event) async {
    if (!widget.enabled || _hold != _Hold.idle) return;
    _hold = _Hold.starting;
    _pressX = event.position.dx;
    _pressY = event.position.dy;
    _lift.value = 0;
    _cancelArmed = false;
    final recorder = _recorder ??= widget.recorder!();
    if (!await recorder.hasPermission()) {
      _hold = _Hold.idle;
      if (mounted) showSnack(context, 'Iuna needs the microphone for dictation. Allow it in Android settings.');
      return;
    }
    // Let go already, or the permission dialog took the touch.
    if (_hold != _Hold.starting || !mounted) {
      _hold = _Hold.idle;
      return;
    }
    try {
      await recorder.start();
    } catch (e) {
      _hold = _Hold.idle;
      if (mounted) showSnack(context, 'The microphone would not start: $e');
      return;
    }
    if (_hold != _Hold.starting || !mounted) {
      await recorder.cancel();
      _hold = _Hold.idle;
      return;
    }
    _levels.clear();
    _levelsSub = recorder.levels.listen(_levels.add);
    _elapsed = Duration.zero;
    _seconds.value = 0;
    _ticker.start();
    HapticFeedback.lightImpact();
    setState(() => _hold = _Hold.recording);
  }

  void _move(PointerMoveEvent event) {
    if (_hold != _Hold.recording) return;
    final up = _pressY - event.position.dy;
    if (up >= _lockDistance) {
      _lift.value = 0;
      HapticFeedback.mediumImpact();
      setState(() {
        _hold = _Hold.locked;
        _cancelArmed = false;
      });
      return;
    }
    _lift.value = (up / _lockDistance).clamp(0.0, 1.0);
    final armed = _pressX - event.position.dx > _cancelDistance;
    if (armed == _cancelArmed) return;
    HapticFeedback.selectionClick();
    setState(() => _cancelArmed = armed);
  }

  /// The finger is up — or [aborted], when the system took the touch.
  /// A locked recording ignores both: it is no longer held.
  Future<void> _release({bool aborted = false}) async {
    switch (_hold) {
      case _Hold.idle || _Hold.stopping || _Hold.locked:
        return;
      case _Hold.starting:
        // [_press] finds this once the platform answers, and undoes it.
        _hold = _Hold.stopping;
        if (!aborted) _nudgeHold();
      case _Hold.recording:
        final cancelled = aborted || _cancelArmed;
        await _stop(cancelled: cancelled, tooShort: !cancelled && _elapsed < _minLength);
    }
  }

  /// Ends the recording: [cancelled] or [tooShort] throw it away, else
  /// the clip goes off to be transcribed.
  Future<void> _stop({required bool cancelled, bool tooShort = false}) async {
    final recorder = _recorder!;
    final length = _elapsed;
    final levels = List<double>.unmodifiable(_levels.values);
    _endRecording();
    if (cancelled || tooShort) {
      await recorder.cancel();
      _hold = _Hold.idle;
      if (tooShort && !cancelled) _nudgeHold();
      return;
    }
    final wav = await recorder.stop();
    _hold = _Hold.idle;
    if (wav == null || !mounted) return;
    HapticFeedback.lightImpact();
    widget.onVoice?.call(VoiceClip(wav: wav, levels: levels, length: length));
  }

  void _sendLocked() {
    if (_hold == _Hold.locked) unawaited(_stop(cancelled: false));
  }

  void _cancelLocked() {
    if (_hold == _Hold.locked) unawaited(_stop(cancelled: true));
  }

  /// Back to the field while the platform finishes with the recording.
  void _endRecording() {
    _ticker.stop();
    _levelsSub?.cancel();
    _levelsSub = null;
    _hold = _Hold.stopping;
    _cancelArmed = false;
    if (mounted) setState(() {});
  }

  void _nudgeHold() {
    if (!mounted) return;
    _nudgeTimer?.cancel();
    setState(() => _nudge = 'Hold the mic while you speak');
    _nudgeTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _nudge = null);
    });
  }

  /// Camera or gallery, then the photo waits above the field until the
  /// message it belongs to is sent.
  Future<void> _attach() async {
    final source = await showModalBottomSheet<PhotoSource>(
      context: context,
      backgroundColor: IunaPalette.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(IunaRadii.lg)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded, color: IunaPalette.ink2),
              title: const Text('Take a photo'),
              onTap: () => Navigator.of(context).pop(PhotoSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: IunaPalette.ink2),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.of(context).pop(PhotoSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    try {
      final photo = await widget.picker!.pick(source);
      if (photo != null) widget.onPhoto!(photo);
    } catch (e) {
      if (mounted) showSnack(context, 'That photo could not be attached: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final locked = _hold == _Hold.locked;
    final recording = locked || _hold == _Hold.recording;
    final bar = Container(
      padding: const EdgeInsets.fromLTRB(16, 2, 4, 2),
      decoration: BoxDecoration(
        color: const Color(0xE6FFFDF6),
        borderRadius: BorderRadius.circular(IunaRadii.xl),
        border: Border.all(color: const Color.fromRGBO(74, 53, 32, 0.08), width: 0.5),
        boxShadow: panelShadow(),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.photo case final photo? when !recording)
            PhotoAttachmentStrip(photo: photo, onRemove: () => widget.onPhoto?.call(null)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    // Kept in place while recording, so focus and height hold.
                    Visibility(
                      visible: !recording,
                      maintainState: true,
                      maintainAnimation: true,
                      maintainSize: true,
                      child: TextField(
                        controller: widget.controller,
                        enabled: widget.enabled,
                        minLines: 1,
                        maxLines: 5,
                        keyboardType: TextInputType.multiline,
                        textCapitalization: TextCapitalization.sentences,
                        style: const TextStyle(fontSize: 14, color: IunaPalette.ink),
                        decoration: InputDecoration(
                          hintText: _nudge ?? widget.hint,
                          hintStyle: const TextStyle(color: IunaPalette.inkMute),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    if (recording)
                      Positioned.fill(
                        child: _RecordingBar(
                          seconds: _seconds,
                          levels: _levels,
                          cancelArmed: _cancelArmed,
                          locked: locked,
                          onCancel: _cancelLocked,
                        ),
                      ),
                  ],
                ),
              ),
              // Full mic height, so the two icons sit on one line
              // whatever the bar's height, but narrow: the paperclip
              // belongs with the mic, not with the field.
              if (_canAttach && !recording && widget.photo == null)
                SizedBox(
                  width: 34,
                  height: 48,
                  child: IconButton(
                    tooltip: 'Attach a photo',
                    onPressed: widget.enabled && !widget.busy ? _attach : null,
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      Icons.add_photo_alternate_outlined,
                      size: 24,
                      color:
                          widget.enabled && !widget.busy ? IunaPalette.ink2 : IunaPalette.inkMute,
                    ),
                  ),
                ),
              if (widget.busy)
                IconButton(
                  tooltip: 'Stop',
                  onPressed: widget.onStop,
                  icon: const Icon(Icons.stop_circle_rounded, color: IunaPalette.ink2),
                )
              else if (locked)
                IconButton(
                  tooltip: 'Send',
                  onPressed: _sendLocked,
                  icon: const Icon(
                    Icons.arrow_circle_up_rounded,
                    size: 30,
                    color: IunaPalette.ctaBottom,
                  ),
                )
              else
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: widget.controller,
                  builder: (context, value, _) {
                    final typed = value.text.trim().isNotEmpty;
                    final attached = widget.photo != null;
                    if (_canDictate && !typed && !attached) return _mic(recording);
                    final can = widget.enabled && (typed || attached);
                    return IconButton(
                      tooltip: 'Send',
                      onPressed: can ? widget.onSend : null,
                      icon: Icon(
                        Icons.arrow_circle_up_rounded,
                        size: 30,
                        color: can ? IunaPalette.ctaBottom : IunaPalette.inkMute,
                      ),
                    );
                  },
                ),
            ],
          ),
        ],
      ),
    );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        bar,
        // Floats free of the composer; nothing above it clips.
        if (_hold == _Hold.recording && !_cancelArmed)
          Positioned(right: 10, bottom: 58, child: _LockPill(lift: _lift)),
      ],
    );
  }

  /// A raw [Listener], not a button: recording starts on touch, and the
  /// finger is followed wherever it slides until it lets go.
  Widget _mic(bool active) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _press,
      onPointerMove: _move,
      onPointerUp: (_) => _release(),
      onPointerCancel: (_) => _release(aborted: true),
      child: Semantics(
        button: true,
        enabled: widget.enabled,
        label: 'Hold to speak, slide up to lock',
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: AnimatedScale(
              scale: active ? 1.2 : 1,
              duration: const Duration(milliseconds: 150),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: !active
                      ? Colors.transparent
                      : _cancelArmed
                      ? IunaPalette.raritySsrInk
                      : IunaPalette.ctaBottom,
                ),
                child: Icon(
                  _cancelArmed ? Icons.delete_outline_rounded : Icons.mic_rounded,
                  size: active ? 20 : 26,
                  color: active
                      ? Colors.white
                      : widget.enabled
                      ? IunaPalette.ctaBottom
                      : IunaPalette.inkMute,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The live loudness trace: each level repaints the waveform, and
/// nothing else.
class _Levels extends ChangeNotifier {
  final List<double> values = [];

  void add(double level) {
    values.add(level);
    notifyListeners();
  }

  void clear() => values.clear();
}

class _RecordingBar extends StatefulWidget {
  const _RecordingBar({
    required this.seconds,
    required this.levels,
    required this.cancelArmed,
    required this.locked,
    required this.onCancel,
  });

  final ValueListenable<int> seconds;
  final _Levels levels;
  final bool cancelArmed;

  /// Hands-free: the finger is gone and the bar ends itself.
  final bool locked;
  final VoidCallback onCancel;

  @override
  State<_RecordingBar> createState() => _RecordingBarState();
}

class _RecordingBarState extends State<_RecordingBar> with SingleTickerProviderStateMixin {
  late final AnimationController _blink;

  @override
  void initState() {
    super.initState();
    _blink = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
      lowerBound: 0.35,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final armed = widget.cancelArmed;
    return Row(
      children: [
        if (widget.locked) ...[
          const Icon(Icons.lock_rounded, size: 14, color: IunaPalette.ink2),
          const SizedBox(width: 6),
        ],
        FadeTransition(
          opacity: armed ? const AlwaysStoppedAnimation(0.3) : _blink,
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: IunaPalette.raritySsrInk,
            ),
          ),
        ),
        const SizedBox(width: 8),
        ValueListenableBuilder<int>(
          valueListenable: widget.seconds,
          builder: (context, seconds, _) => Text(
            clockLabel(Duration(seconds: seconds)),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: IunaPalette.ink2,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: armed
              ? const Text(
                  'Release to cancel',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: IunaPalette.raritySsrInk,
                  ),
                )
              : Waveform(
                  levels: widget.levels.values,
                  repaint: widget.levels,
                  color: IunaPalette.ink2.withValues(alpha: 0.75),
                ),
        ),
        if (widget.locked) ...[
          const SizedBox(width: 4),
          TextButton(
            onPressed: widget.onCancel,
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 32),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: IunaPalette.raritySsrInk,
            ),
            child: const Text(
              'Cancel',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ] else if (!armed) ...[
          const SizedBox(width: 8),
          const Text('‹ Slide to cancel', style: TextStyle(fontSize: 11, color: IunaPalette.ink3)),
        ],
      ],
    );
  }
}


/// Telegram's lock: it sits above the mic while the finger holds it, and
/// fills up as the finger climbs toward it.
class _LockPill extends StatelessWidget {
  const _LockPill({required this.lift});

  final ValueListenable<double> lift;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ValueListenableBuilder<double>(
        valueListenable: lift,
        builder: (context, lift, _) {
          final on = lift > 0.5;
          return Transform.translate(
            offset: Offset(0, 8 * (1 - lift)),
            child: Container(
              width: 36,
              height: 54,
              decoration: BoxDecoration(
                color: Color.lerp(const Color(0xF2FFFDF6), IunaPalette.ctaBottom, lift),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: const Color.fromRGBO(74, 53, 32, 0.08),
                  width: 0.5,
                ),
                boxShadow: panelShadow(),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 16,
                    color: on ? Colors.white : IunaPalette.ink2,
                  ),
                  const SizedBox(height: 2),
                  Opacity(
                    opacity: 1 - lift,
                    child: const Icon(
                      Icons.keyboard_arrow_up_rounded,
                      size: 14,
                      color: IunaPalette.ink3,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
