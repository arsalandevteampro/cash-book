import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../screens/app_lock_screen.dart';
import '../services/app_lock_service.dart';

class AppLockWrapper extends StatefulWidget {
  final Widget child;

  const AppLockWrapper({
    super.key,
    required this.child,
  });

  @override
  State<AppLockWrapper> createState() => _AppLockWrapperState();
}

class _AppLockWrapperState extends State<AppLockWrapper> with WidgetsBindingObserver {
  bool _isLocked = false;
  bool _hasInitialCheck = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    final lockService = Provider.of<AppLockService>(context, listen: false);

    if (!lockService.isLockEnabled) return;

    // When app goes to background
    if (state == AppLifecycleState.paused) {
      if (!lockService.isAuthenticating && !_isLocked) {
        setState(() {
          _isLocked = true;
        });
      }
    }
    // When app comes back to foreground / resumed
    else if (state == AppLifecycleState.resumed) {
      if (_isLocked && lockService.isBiometricEnabled && !lockService.isAuthenticating) {
        _checkBiometricsOnResume(lockService);
      }
    }
  }

  Future<void> _checkBiometricsOnResume(AppLockService lockService) async {
    final authenticated = await lockService.authenticateBiometrics();
    if (authenticated && mounted) {
      _onUnlocked();
    }
  }

  void _onUnlocked() {
    setState(() {
      _isLocked = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final lockService = Provider.of<AppLockService>(context);

    // Initial cold-start check when AppLockService is loaded
    if (!_hasInitialCheck && lockService.isLockEnabled) {
      _hasInitialCheck = true;
      _isLocked = true;

      if (lockService.isBiometricEnabled) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _checkBiometricsOnResume(lockService);
        });
      }
    }

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: [
          widget.child,
          if (_isLocked && lockService.isLockEnabled)
            Positioned.fill(
              child: Material(
                type: MaterialType.transparency,
                child: AppLockScreen(
                  mode: AppLockMode.verify,
                  onUnlocked: _onUnlocked,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
