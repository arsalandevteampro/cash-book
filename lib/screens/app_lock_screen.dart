import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_lock_service.dart';
import '../widgets/pattern_lock_canvas.dart';

enum AppLockMode { verify, createPin, createPattern }

class AppLockScreen extends StatefulWidget {
  final AppLockMode mode;
  final VoidCallback? onUnlocked;

  const AppLockScreen({
    super.key,
    this.mode = AppLockMode.verify,
    this.onUnlocked,
  });

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  String _enteredPin = '';
  String _tempPin = ''; // Used during createPin confirmation
  List<int> _tempPattern = []; // Used during createPattern confirmation

  bool _isError = false;
  bool _isSuccess = false;
  String _statusText = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initLockState();
    });
  }

  Future<void> _initLockState() async {
    final lockService = Provider.of<AppLockService>(context, listen: false);

    if (widget.mode == AppLockMode.verify) {
      setState(() {
        _statusText = lockService.lockType == 'pattern'
            ? 'Draw your pattern to unlock'
            : 'Enter your 4-digit PIN';
      });
    } else if (widget.mode == AppLockMode.createPin) {
      setState(() {
        _statusText = 'Enter a new 4-digit PIN';
      });
    } else if (widget.mode == AppLockMode.createPattern) {
      setState(() {
        _statusText = 'Draw a new pattern (min 4 dots)';
      });
    }
  }

  Future<void> _triggerBiometricAuth(AppLockService lockService) async {
    final authenticated = await lockService.authenticateBiometrics();
    if (authenticated && mounted) {
      _unlockSuccess();
    }
  }

  void _unlockSuccess() {
    setState(() {
      _isSuccess = true;
      _isError = false;
    });

    if (widget.onUnlocked != null) {
      widget.onUnlocked!();
    } else {
      Navigator.of(context).maybePop(true);
    }
  }

  void _triggerError(String msg) {
    setState(() {
      _isError = true;
      _statusText = msg;
      _enteredPin = '';
    });

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        setState(() {
          _isError = false;
          final lockService = Provider.of<AppLockService>(context, listen: false);
          _statusText = lockService.lockType == 'pattern'
              ? 'Draw your pattern to unlock'
              : 'Enter your 4-digit PIN';
        });
      }
    });
  }

  // --- PIN Keypad Handling ---
  void _onKeyPress(String val) {
    if (_enteredPin.length < 4) {
      setState(() {
        _enteredPin += val;
      });

      if (_enteredPin.length == 4) {
        _onPinComplete(_enteredPin);
      }
    }
  }

  void _onBackspace() {
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      });
    }
  }

  void _onPinComplete(String pin) {
    final lockService = Provider.of<AppLockService>(context, listen: false);

    if (widget.mode == AppLockMode.verify) {
      if (pin == lockService.savedPin) {
        _unlockSuccess();
      } else {
        _triggerError('Incorrect PIN. Try again.');
      }
    } else if (widget.mode == AppLockMode.createPin) {
      if (_tempPin.isEmpty) {
        // Step 1: Save temp PIN and prompt confirm
        setState(() {
          _tempPin = pin;
          _enteredPin = '';
          _statusText = 'Re-enter your 4-digit PIN to confirm';
        });
      } else {
        // Step 2: Confirm PIN
        if (pin == _tempPin) {
          lockService.setPin(pin);
          lockService.setLockType('pin');
          lockService.setLockEnabled(true);
          Navigator.of(context).pop(true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PIN Lock set successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          setState(() {
            _tempPin = '';
            _triggerError('PINs did not match. Try setting up again.');
          });
        }
      }
    }
  }

  // --- Pattern Handling ---
  void _onPatternComplete(List<int> patternIndices) {
    if (patternIndices.length < 4) {
      _triggerError('Connect at least 4 dots');
      return;
    }

    final patternStr = patternIndices.join(',');
    final lockService = Provider.of<AppLockService>(context, listen: false);

    if (widget.mode == AppLockMode.verify) {
      if (patternStr == lockService.savedPattern) {
        _unlockSuccess();
      } else {
        _triggerError('Incorrect Pattern. Try again.');
      }
    } else if (widget.mode == AppLockMode.createPattern) {
      if (_tempPattern.isEmpty) {
        // Step 1: Save temp pattern
        setState(() {
          _tempPattern = patternIndices;
          _statusText = 'Draw pattern again to confirm';
        });
      } else {
        // Step 2: Confirm pattern
        final tempPatternStr = _tempPattern.join(',');
        if (patternStr == tempPatternStr) {
          lockService.setPattern(patternStr);
          lockService.setLockType('pattern');
          lockService.setLockEnabled(true);
          Navigator.of(context).pop(true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Pattern Lock set successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          setState(() {
            _tempPattern = [];
            _triggerError('Patterns did not match. Try again.');
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lockService = Provider.of<AppLockService>(context);
    final activeLockType = widget.mode == AppLockMode.createPattern
        ? 'pattern'
        : widget.mode == AppLockMode.createPin
            ? 'pin'
            : lockService.lockType;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            children: [
              // Header Close / Back Button if creating
              if (widget.mode != AppLockMode.verify)
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                )
              else
                const SizedBox(height: 24),

              const Spacer(flex: 1),

              // Lock Icon Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _isError
                      ? Colors.red.withValues(alpha: 0.15)
                      : _isSuccess
                          ? Colors.green.withValues(alpha: 0.15)
                          : theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isError
                      ? Icons.lock_clock_rounded
                      : _isSuccess
                          ? Icons.lock_open_rounded
                          : Icons.lock_rounded,
                  size: 40,
                  color: _isError
                      ? Colors.red
                      : _isSuccess
                          ? Colors.green
                          : theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Cash Book',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _statusText,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: _isError
                      ? Colors.red
                      : theme.colorScheme.onSurfaceVariant,
                  fontWeight: _isError ? FontWeight.bold : FontWeight.normal,
                ),
              ),

              const Spacer(flex: 1),

              // Lock View: PIN vs Pattern
              if (activeLockType == 'pin') ...[
                // PIN Dots Indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (index) {
                    final isFilled = index < _enteredPin.length;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isFilled
                            ? (_isError ? Colors.red : theme.colorScheme.primary)
                            : Colors.transparent,
                        border: Border.all(
                          color: _isError
                              ? Colors.red
                              : isFilled
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                          width: 2,
                        ),
                      ),
                    );
                  }),
                ),
                const Spacer(flex: 1),

                // PIN Keypad
                _buildPinKeypad(theme, lockService),
              ] else ...[
                // Pattern View Canvas
                Container(
                  constraints: const BoxConstraints(maxWidth: 300, maxHeight: 300),
                  child: PatternLockCanvas(
                    isError: _isError,
                    isSuccess: _isSuccess,
                    onComplete: _onPatternComplete,
                  ),
                ),
                const Spacer(flex: 1),

                // Fingerprint shortcut button in Pattern mode
                if (widget.mode == AppLockMode.verify && lockService.isBiometricEnabled)
                  TextButton.icon(
                    onPressed: () => _triggerBiometricAuth(lockService),
                    icon: const Icon(Icons.fingerprint_rounded, size: 24),
                    label: const Text('Unlock with Fingerprint'),
                  ),
              ],

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPinKeypad(ThemeData theme, AppLockService lockService) {
    return Column(
      children: [
        for (var row in [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: row.map((num) => _buildKeypadButton(num, theme)).toList(),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Left action: Biometrics Fingerprint button if verify mode
              if (widget.mode == AppLockMode.verify && lockService.isBiometricEnabled)
                InkWell(
                  onTap: () => _triggerBiometricAuth(lockService),
                  borderRadius: BorderRadius.circular(36),
                  child: Container(
                    width: 72,
                    height: 72,
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.fingerprint_rounded,
                      size: 32,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                )
              else
                const SizedBox(width: 72, height: 72),

              // Number 0
              _buildKeypadButton('0', theme),

              // Right action: Backspace
              InkWell(
                onTap: _onBackspace,
                borderRadius: BorderRadius.circular(36),
                child: Container(
                  width: 72,
                  height: 72,
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.backspace_outlined,
                    size: 24,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildKeypadButton(String number, ThemeData theme) {
    return Material(
      color: theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.6),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => _onKeyPress(number),
        child: Container(
          width: 72,
          height: 72,
          alignment: Alignment.center,
          child: Text(
            number,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
