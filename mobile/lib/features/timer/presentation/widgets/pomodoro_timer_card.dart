import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/theme/chronolog_theme.dart';
import '../../../../shared/utils/time_utils.dart';
import '../../domain/pomodoro_model.dart';
import '../timer_controller.dart';

/// Formats duration in seconds into a compact string:
/// e.g. `45s`, `5m 20s`, `1h 15m`.
String _formatDetailedDuration(int totalSeconds) {
  final s = totalSeconds < 0 ? 0 : totalSeconds;
  final h = s ~/ 3600;
  final m = (s % 3600) ~/ 60;
  final sec = s % 60;
  if (h > 0) return '${h}h ${m}m';
  if (m > 0) return '${m}m ${sec}s';
  return '${sec}s';
}

/// Dashboard card providing complete Pomodoro focus session tracking,
/// configuration with "I WILL WORK" button, and segregated time accounting.
class PomodoroTimerCard extends ConsumerStatefulWidget {
  const PomodoroTimerCard({super.key});

  @override
  ConsumerState<PomodoroTimerCard> createState() => _PomodoroTimerCardState();
}

class _PomodoroTimerCardState extends ConsumerState<PomodoroTimerCard> {
  // Configuration options
  int _focusMinutes = 25;
  int _shortBreakMinutes = 5;
  int _longBreakMinutes = 15;
  int _totalSessions = 4;
  int _longBreakInterval = 4;
  bool _autoStartBreaks = true;
  bool _autoStartFocus = true;
  bool _isStarting = false;

  // Custom focus duration state
  bool _isCustomFocus = false;
  late final TextEditingController _customFocusController;

  // Custom short break duration state
  bool _isCustomShortBreak = false;
  late final TextEditingController _customShortBreakController;

  // Custom long break duration state
  bool _isCustomLongBreak = false;
  late final TextEditingController _customLongBreakController;

  @override
  void initState() {
    super.initState();
    _customFocusController = TextEditingController();
    _customShortBreakController = TextEditingController();
    _customLongBreakController = TextEditingController();
  }

  @override
  void dispose() {
    _customFocusController.dispose();
    _customShortBreakController.dispose();
    _customLongBreakController.dispose();
    super.dispose();
  }

  bool get _isCustomFocusValid {
    if (!_isCustomFocus) return true;
    final trimmed = _customFocusController.text.trim();
    if (trimmed.isEmpty) return false;
    final val = int.tryParse(trimmed);
    return val != null && val >= 1 && val <= 180 && val.toString() == trimmed;
  }

  bool get _isCustomShortBreakValid {
    if (!_isCustomShortBreak) return true;
    final trimmed = _customShortBreakController.text.trim();
    if (trimmed.isEmpty) return false;
    final val = int.tryParse(trimmed);
    return val != null && val >= 1 && val <= 60 && val.toString() == trimmed;
  }

  bool get _isCustomLongBreakValid {
    if (!_isCustomLongBreak) return true;
    final trimmed = _customLongBreakController.text.trim();
    if (trimmed.isEmpty) return false;
    final val = int.tryParse(trimmed);
    return val != null && val >= 1 && val <= 90 && val.toString() == trimmed;
  }

  void _onPresetSelect(int mins) {
    setState(() {
      _isCustomFocus = false;
      _focusMinutes = mins;
    });
  }

  void _onCustomSelect() {
    setState(() {
      _isCustomFocus = true;
      if (_customFocusController.text.trim().isEmpty) {
        _customFocusController.text = '$_focusMinutes';
      } else {
        final parsed = int.tryParse(_customFocusController.text.trim());
        if (parsed != null && parsed >= 1 && parsed <= 180) {
          _focusMinutes = parsed;
        }
      }
    });
  }

  void _onCustomFocusChanged(String val) {
    final trimmed = val.trim();
    final parsed = int.tryParse(trimmed);
    setState(() {
      if (parsed != null && parsed >= 1 && parsed <= 180 && parsed.toString() == trimmed) {
        _focusMinutes = parsed;
      }
    });
  }

  void _onShortBreakPresetSelect(int mins) {
    setState(() {
      _isCustomShortBreak = false;
      _shortBreakMinutes = mins;
    });
  }

  void _onCustomShortBreakSelect() {
    setState(() {
      _isCustomShortBreak = true;
      if (_customShortBreakController.text.trim().isEmpty) {
        _customShortBreakController.text = '$_shortBreakMinutes';
      } else {
        final parsed = int.tryParse(_customShortBreakController.text.trim());
        if (parsed != null && parsed >= 1 && parsed <= 60) {
          _shortBreakMinutes = parsed;
        }
      }
    });
  }

  void _onCustomShortBreakChanged(String val) {
    final trimmed = val.trim();
    final parsed = int.tryParse(trimmed);
    setState(() {
      if (parsed != null && parsed >= 1 && parsed <= 60 && parsed.toString() == trimmed) {
        _shortBreakMinutes = parsed;
      }
    });
  }

  void _onLongBreakPresetSelect(int mins) {
    setState(() {
      _isCustomLongBreak = false;
      _longBreakMinutes = mins;
    });
  }

  void _onCustomLongBreakSelect() {
    setState(() {
      _isCustomLongBreak = true;
      if (_customLongBreakController.text.trim().isEmpty) {
        _customLongBreakController.text = '$_longBreakMinutes';
      } else {
        final parsed = int.tryParse(_customLongBreakController.text.trim());
        if (parsed != null && parsed >= 1 && parsed <= 90) {
          _longBreakMinutes = parsed;
        }
      }
    });
  }

  void _onCustomLongBreakChanged(String val) {
    final trimmed = val.trim();
    final parsed = int.tryParse(trimmed);
    setState(() {
      if (parsed != null && parsed >= 1 && parsed <= 90 && parsed.toString() == trimmed) {
        _longBreakMinutes = parsed;
      }
    });
  }

  Future<void> _handleStartWork() async {
    if (_isCustomFocus && !_isCustomFocusValid) return;
    if (_isCustomShortBreak && !_isCustomShortBreakValid) return;
    if (_isCustomLongBreak && !_isCustomLongBreakValid) return;
    setState(() => _isStarting = true);
    try {
      await ref.read(pomodoroTimerProvider.notifier).startPlan(
            focusDurationSeconds: _focusMinutes * 60,
            shortBreakDurationSeconds: _shortBreakMinutes * 60,
            longBreakDurationSeconds: _longBreakMinutes * 60,
            totalSessions: _totalSessions,
            longBreakInterval: _longBreakInterval,
            autoStartBreaks: _autoStartBreaks,
            autoStartFocus: _autoStartFocus,
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start focus session: $e'),
            backgroundColor: ChronologTheme.red950,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isStarting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1-second reactive ticker triggers smooth UI rebuilds without network calls
    ref.watch(pomodoroTickerStreamProvider);

    final rawPlan = ref.watch(pomodoroTimerProvider);
    final plan = rawPlan?.advanceToTime(TimeUtils.now());
    final notifier = ref.read(pomodoroTimerProvider.notifier);

    final isConfiguring =
        plan == null || plan.isCompleted || plan.isCancelled;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: isConfiguring
            ? _buildConfigurationView(plan)
            : _buildActiveSessionView(plan, notifier),
      ),
    );
  }

  // ── Mode 1: Configuration Form ("I WILL WORK") ─────────────────────────────
  Widget _buildConfigurationView(PomodoroPlanModel? plan) {
    final isCompleted = plan != null && plan.isCompleted;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: ChronologTheme.cyan950,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    Icons.timer_outlined,
                    color: ChronologTheme.cyan400,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Focus Session Setup',
                  style: TextStyle(
                    color: ChronologTheme.zinc50,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            if (isCompleted)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: ChronologTheme.emerald950,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: ChronologTheme.emerald400.withValues(alpha: 0.4)),
                ),
                child: const Text(
                  'Completed!',
                  style: TextStyle(
                    color: ChronologTheme.emerald400,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: ChronologTheme.zinc800,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Ready',
                  style: TextStyle(
                    color: ChronologTheme.zinc400,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Configure your intervals and commit to deep work.',
          style: TextStyle(
            color: ChronologTheme.zinc400,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 12),

        // Completed celebration banner
        if (isCompleted) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: ChronologTheme.emerald950.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: ChronologTheme.emerald400.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '🎉 Great job! You finished ${plan.completedSessions} focus ${plan.completedSessions == 1 ? "session" : "sessions"}.',
                  style: const TextStyle(
                    color: ChronologTheme.emerald400,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Focus: ${_formatDetailedDuration(plan.totalFocusSeconds)} • Break: ${_formatDetailedDuration(plan.totalBreakSeconds)} • Paused: ${_formatDetailedDuration(plan.totalPausedSeconds)}',
                  style: const TextStyle(
                    color: ChronologTheme.zinc400,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        // Focus duration selection
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Focus Duration',
              style: TextStyle(
                color: ChronologTheme.zinc300,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              _isCustomFocus && (!_isCustomFocusValid || _customFocusController.text.trim().isEmpty)
                  ? 'Custom'
                  : '$_focusMinutes min',
              style: const TextStyle(
                color: ChronologTheme.cyan400,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            ...[15, 25, 45, 50].map((mins) {
              final isSelected = !_isCustomFocus && _focusMinutes == mins;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: InkWell(
                    onTap: () => _onPresetSelect(mins),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? ChronologTheme.cyan950 : ChronologTheme.zinc950,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isSelected
                              ? ChronologTheme.cyan400
                              : ChronologTheme.zinc800,
                          width: isSelected ? 1.5 : 1.0,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${mins}m',
                        style: TextStyle(
                          color: isSelected ? ChronologTheme.cyan300 : ChronologTheme.zinc400,
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: InkWell(
                  onTap: _onCustomSelect,
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: _isCustomFocus ? ChronologTheme.cyan950 : ChronologTheme.zinc950,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: _isCustomFocus
                            ? ChronologTheme.cyan400
                            : ChronologTheme.zinc800,
                        width: _isCustomFocus ? 1.5 : 1.0,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Custom',
                      style: TextStyle(
                        color: _isCustomFocus ? ChronologTheme.cyan300 : ChronologTheme.zinc400,
                        fontSize: 11,
                        fontWeight: _isCustomFocus ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (_isCustomFocus) ...[
          const SizedBox(height: 8),
          TextField(
            controller: _customFocusController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(
              color: ChronologTheme.zinc50,
              fontSize: 13,
            ),
            decoration: InputDecoration(
              hintText: 'Enter minutes (1–180)',
              hintStyle: const TextStyle(
                color: ChronologTheme.zinc500,
                fontSize: 12,
              ),
              suffixText: 'min',
              suffixStyle: const TextStyle(
                color: ChronologTheme.zinc400,
                fontSize: 12,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              filled: true,
              fillColor: ChronologTheme.zinc950,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: ChronologTheme.zinc800),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: ChronologTheme.zinc800),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: ChronologTheme.cyan400),
              ),
              errorText: _customFocusController.text.trim().isEmpty
                  ? 'Please enter a duration'
                  : !_isCustomFocusValid
                      ? 'Enter 1 to 180 minutes'
                      : null,
              errorStyle: const TextStyle(
                color: ChronologTheme.red400,
                fontSize: 11,
              ),
            ),
            onChanged: _onCustomFocusChanged,
          ),
        ],
        const SizedBox(height: 14),

        // Break Durations (Short Break & Long Break)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Short Break',
                        style: TextStyle(
                          color: ChronologTheme.zinc300,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        _isCustomShortBreak && (!_isCustomShortBreakValid || _customShortBreakController.text.trim().isEmpty)
                            ? 'Custom'
                            : '${_shortBreakMinutes}m',
                        style: const TextStyle(
                          color: ChronologTheme.emerald400,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      ...[5, 10].map((m) {
                        final isSelected = !_isCustomShortBreak && _shortBreakMinutes == m;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: InkWell(
                              onTap: () => _onShortBreakPresetSelect(m),
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                decoration: BoxDecoration(
                                  color: isSelected ? ChronologTheme.emerald950 : ChronologTheme.zinc950,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isSelected
                                        ? ChronologTheme.emerald400
                                        : ChronologTheme.zinc800,
                                    width: isSelected ? 1.5 : 1.0,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '${m}m',
                                  style: TextStyle(
                                    color: isSelected ? ChronologTheme.emerald400 : ChronologTheme.zinc400,
                                    fontSize: 11,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: InkWell(
                            onTap: _onCustomShortBreakSelect,
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              decoration: BoxDecoration(
                                color: _isCustomShortBreak ? ChronologTheme.emerald950 : ChronologTheme.zinc950,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: _isCustomShortBreak
                                      ? ChronologTheme.emerald400
                                      : ChronologTheme.zinc800,
                                  width: _isCustomShortBreak ? 1.5 : 1.0,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'Custom',
                                style: TextStyle(
                                  color: _isCustomShortBreak ? ChronologTheme.emerald400 : ChronologTheme.zinc400,
                                  fontSize: 10,
                                  fontWeight: _isCustomShortBreak ? FontWeight.bold : FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_isCustomShortBreak) ...[
                    const SizedBox(height: 6),
                    TextField(
                      controller: _customShortBreakController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: const TextStyle(
                        color: ChronologTheme.zinc50,
                        fontSize: 12,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Min (1–60)',
                        hintStyle: const TextStyle(
                          color: ChronologTheme.zinc500,
                          fontSize: 11,
                        ),
                        suffixText: 'm',
                        suffixStyle: const TextStyle(
                          color: ChronologTheme.zinc400,
                          fontSize: 11,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        filled: true,
                        fillColor: ChronologTheme.zinc950,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: const BorderSide(color: ChronologTheme.zinc800),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: const BorderSide(color: ChronologTheme.zinc800),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: const BorderSide(color: ChronologTheme.emerald400),
                        ),
                        errorText: _customShortBreakController.text.trim().isEmpty
                            ? 'Required'
                            : !_isCustomShortBreakValid
                                ? 'Enter 1–60 min'
                                : null,
                        errorStyle: const TextStyle(
                          color: ChronologTheme.red400,
                          fontSize: 10,
                        ),
                      ),
                      onChanged: _onCustomShortBreakChanged,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Long Break',
                        style: TextStyle(
                          color: ChronologTheme.zinc300,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        _isCustomLongBreak && (!_isCustomLongBreakValid || _customLongBreakController.text.trim().isEmpty)
                            ? 'Custom'
                            : '${_longBreakMinutes}m',
                        style: const TextStyle(
                          color: Color(0xFF818CF8),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      ...[15, 20].map((m) {
                        final isSelected = !_isCustomLongBreak && _longBreakMinutes == m;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: InkWell(
                              onTap: () => _onLongBreakPresetSelect(m),
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                decoration: BoxDecoration(
                                  color: isSelected ? const Color(0xFF1E1B4B) : ChronologTheme.zinc950,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFF818CF8)
                                        : ChronologTheme.zinc800,
                                    width: isSelected ? 1.5 : 1.0,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '${m}m',
                                  style: TextStyle(
                                    color: isSelected ? const Color(0xFF818CF8) : ChronologTheme.zinc400,
                                    fontSize: 11,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: InkWell(
                            onTap: _onCustomLongBreakSelect,
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              decoration: BoxDecoration(
                                color: _isCustomLongBreak ? const Color(0xFF1E1B4B) : ChronologTheme.zinc950,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: _isCustomLongBreak
                                      ? const Color(0xFF818CF8)
                                      : ChronologTheme.zinc800,
                                  width: _isCustomLongBreak ? 1.5 : 1.0,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'Custom',
                                style: TextStyle(
                                  color: _isCustomLongBreak ? const Color(0xFF818CF8) : ChronologTheme.zinc400,
                                  fontSize: 10,
                                  fontWeight: _isCustomLongBreak ? FontWeight.bold : FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_isCustomLongBreak) ...[
                    const SizedBox(height: 6),
                    TextField(
                      controller: _customLongBreakController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: const TextStyle(
                        color: ChronologTheme.zinc50,
                        fontSize: 12,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Min (1–90)',
                        hintStyle: const TextStyle(
                          color: ChronologTheme.zinc500,
                          fontSize: 11,
                        ),
                        suffixText: 'm',
                        suffixStyle: const TextStyle(
                          color: ChronologTheme.zinc400,
                          fontSize: 11,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        filled: true,
                        fillColor: ChronologTheme.zinc950,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: const BorderSide(color: ChronologTheme.zinc800),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: const BorderSide(color: ChronologTheme.zinc800),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: const BorderSide(color: Color(0xFF818CF8)),
                        ),
                        errorText: _customLongBreakController.text.trim().isEmpty
                            ? 'Required'
                            : !_isCustomLongBreakValid
                                ? 'Enter 1–90 min'
                                : null,
                        errorStyle: const TextStyle(
                          color: ChronologTheme.red400,
                          fontSize: 10,
                        ),
                      ),
                      onChanged: _onCustomLongBreakChanged,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Total Sessions & Interval dropdowns
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Total Sessions',
                    style: TextStyle(
                      color: ChronologTheme.zinc300,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: ChronologTheme.zinc950,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: ChronologTheme.zinc800),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _totalSessions,
                        isExpanded: true,
                        dropdownColor: ChronologTheme.zinc900,
                        items: [2, 3, 4, 6, 8].map((n) {
                          return DropdownMenuItem<int>(
                            value: n,
                            child: Text(
                              '$n sessions',
                              style: const TextStyle(
                                color: ChronologTheme.zinc200,
                                fontSize: 12,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _totalSessions = val);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Long Break Every',
                    style: TextStyle(
                      color: ChronologTheme.zinc300,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: ChronologTheme.zinc950,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: ChronologTheme.zinc800),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _longBreakInterval,
                        isExpanded: true,
                        dropdownColor: ChronologTheme.zinc900,
                        items: [2, 3, 4].map((n) {
                          return DropdownMenuItem<int>(
                            value: n,
                            child: Text(
                              '${n}th session',
                              style: const TextStyle(
                                color: ChronologTheme.zinc200,
                                fontSize: 12,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _longBreakInterval = val);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Auto-start options
        Row(
          children: [
            Checkbox(
              value: _autoStartBreaks,
              activeColor: ChronologTheme.cyan400,
              checkColor: ChronologTheme.zinc950,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
              onChanged: (val) => setState(() => _autoStartBreaks = val ?? false),
            ),
            const Text(
              'Auto-start breaks',
              style: TextStyle(
                color: ChronologTheme.zinc300,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 16),
            Checkbox(
              value: _autoStartFocus,
              activeColor: ChronologTheme.cyan400,
              checkColor: ChronologTheme.zinc950,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
              onChanged: (val) => setState(() => _autoStartFocus = val ?? false),
            ),
            const Text(
              'Auto-start focus',
              style: TextStyle(
                color: ChronologTheme.zinc300,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // PROMINENT "I WILL WORK" BUTTON
        Builder(
          builder: (context) {
            final isButtonDisabled = _isStarting ||
                (_isCustomFocus && !_isCustomFocusValid) ||
                (_isCustomShortBreak && !_isCustomShortBreakValid) ||
                (_isCustomLongBreak && !_isCustomLongBreakValid);
            return SizedBox(
              width: double.infinity,
              height: 48,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: isButtonDisabled
                      ? null
                      : const LinearGradient(
                          colors: [
                            Color(0xFF22D3EE), // cyan-400
                            Color(0xFF67E8F9), // cyan-300
                          ],
                        ),
                  color: isButtonDisabled ? ChronologTheme.zinc800 : null,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: isButtonDisabled
                      ? []
                      : [
                          BoxShadow(
                            color: const Color(0xFF06B6D4).withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                ),
                child: ElevatedButton(
                  onPressed: isButtonDisabled ? null : _handleStartWork,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    disabledBackgroundColor: Colors.transparent,
                    disabledForegroundColor: ChronologTheme.zinc500,
                    foregroundColor: ChronologTheme.zinc950,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: EdgeInsets.zero,
                  ),
                  child: _isStarting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: ChronologTheme.zinc950,
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.play_arrow,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'I WILL WORK',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // ── Mode 2: Active Session View ────────────────────────────────────────────
  Widget _buildActiveSessionView(PomodoroPlanModel plan, PomodoroNotifier notifier) {
    final remaining = plan.remainingDuration;
    final isPaused = plan.isPaused;

    // Progress calculation
    final totalPhaseDuration = plan.currentPhase == 'focus'
        ? plan.focusDurationSeconds
        : (plan.currentPhase == 'longBreak'
            ? plan.longBreakDurationSeconds
            : plan.shortBreakDurationSeconds);
    final progress = totalPhaseDuration <= 0
        ? 1.0
        : ((totalPhaseDuration - remaining.inSeconds) / totalPhaseDuration)
            .clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with Phase and Session Counter
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildPhaseBadge(plan.status, plan.currentPhase),
            Text(
              plan.currentPhase == 'focus'
                  ? 'Session ${plan.currentSession} of ${plan.totalSessions}'
                  : 'Next: Session ${plan.currentSession} of ${plan.totalSessions}',
              style: const TextStyle(
                color: ChronologTheme.zinc400,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Attached Task Banner
        if (plan.taskTitle != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: ChronologTheme.cyan950.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: ChronologTheme.cyan400.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.task_alt,
                  color: ChronologTheme.cyan400,
                  size: 14,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Focusing on: ${plan.taskTitle}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: ChronologTheme.cyan300,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],

        // Digital Countdown Timer
        Center(
          child: Column(
            children: [
              Text(
                TimeUtils.formatDigital(remaining.inSeconds),
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 48,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1.0,
                  color: ChronologTheme.zinc50,
                ),
              ),
              Text(
                isPaused ? 'TIMER PAUSED' : 'TIME REMAINING',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w600,
                  color: isPaused
                      ? const Color(0xFFFBBF24)
                      : ChronologTheme.zinc500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Linear Progress Bar
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 5,
            backgroundColor: ChronologTheme.zinc800,
            color: isPaused
                ? const Color(0xFFFBBF24)
                : (plan.currentPhase == 'focus'
                    ? ChronologTheme.cyan400
                    : ChronologTheme.emerald400),
          ),
        ),
        const SizedBox(height: 14),

        // Distinct Time Accounting (Segregated Focus, Break, Paused)
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: ChronologTheme.zinc950,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ChronologTheme.zinc800),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    const Text(
                      'FOCUS',
                      style: TextStyle(
                        color: ChronologTheme.cyan400,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatDetailedDuration(plan.liveFocusSeconds),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        color: ChronologTheme.zinc200,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 28, color: ChronologTheme.zinc800),
              Expanded(
                child: Column(
                  children: [
                    const Text(
                      'BREAK',
                      style: TextStyle(
                        color: ChronologTheme.emerald400,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatDetailedDuration(plan.liveBreakSeconds),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        color: ChronologTheme.zinc200,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 28, color: ChronologTheme.zinc800),
              Expanded(
                child: Column(
                  children: [
                    const Text(
                      'PAUSED',
                      style: TextStyle(
                        color: Color(0xFFFBBF24),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatDetailedDuration(plan.livePausedSeconds),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        color: ChronologTheme.zinc200,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Controls (Pause/Resume, Skip, Cancel)
        Row(
          children: [
            Expanded(
              flex: 3,
              child: isPaused
                  ? ElevatedButton.icon(
                      onPressed: () => notifier.resume(),
                      icon: const Icon(Icons.play_arrow, size: 18),
                      label: const Text('Resume'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ChronologTheme.cyan400,
                        foregroundColor: ChronologTheme.zinc950,
                      ),
                    )
                  : ElevatedButton.icon(
                      onPressed: () => notifier.pause(),
                      icon: const Icon(Icons.pause, size: 18),
                      label: const Text('Pause'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ChronologTheme.zinc800,
                        foregroundColor: ChronologTheme.zinc200,
                      ),
                    ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: OutlinedButton.icon(
                onPressed: () => notifier.skipPhase(),
                icon: const Icon(Icons.skip_next, size: 18),
                label: const Text('Skip'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: ChronologTheme.zinc300,
                  side: const BorderSide(color: ChronologTheme.zinc800),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () => notifier.cancelPlan(),
              icon: const Icon(Icons.stop, size: 20),
              tooltip: 'Cancel Session',
              style: IconButton.styleFrom(
                foregroundColor: ChronologTheme.zinc400,
                backgroundColor: ChronologTheme.zinc800,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPhaseBadge(String status, String currentPhase) {
    String label;
    Color bg;
    Color fg;
    Color border;

    if (status == 'paused') {
      label = 'PAUSED';
      bg = const Color(0xFF451A03);
      fg = const Color(0xFFFBBF24);
      border = const Color(0xFF78350F);
    } else if (currentPhase == 'focus') {
      label = 'FOCUS PHASE';
      bg = ChronologTheme.cyan950;
      fg = ChronologTheme.cyan400;
      border = const Color(0xFF0E7490);
    } else if (currentPhase == 'longBreak') {
      label = 'LONG BREAK';
      bg = const Color(0xFF1E1B4B);
      fg = const Color(0xFF818CF8);
      border = const Color(0xFF3730A3);
    } else {
      label = 'SHORT BREAK';
      bg = ChronologTheme.emerald950;
      fg = ChronologTheme.emerald400;
      border = const Color(0xFF065F46);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
