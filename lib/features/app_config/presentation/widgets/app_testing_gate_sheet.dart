import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../services/google_drive_service.dart';
import '../../../more_apps/data/models/app_model.dart';
import '../../data/models/access_request_model.dart';
import '../../services/access_request_rate_limiter.dart';
import '../providers/app_config_providers.dart';

class AppTestingGateSheet extends ConsumerStatefulWidget {
  final AppModel? app;
  const AppTestingGateSheet({super.key, this.app});

  static Future<void> show(BuildContext context, [AppModel? app]) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AppTestingGateSheet(app: app),
    );
  }

  @override
  ConsumerState<AppTestingGateSheet> createState() => _AppTestingGateSheetState();
}

class _AppTestingGateSheetState extends ConsumerState<AppTestingGateSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  bool _isSubmitting = false;
  bool _isGoogleSigningIn = false;
  bool _isEditingAfterApproval = false;
  String? _rateLimitError;

  @override
  void initState() {
    super.initState();
    _checkSilentSignIn();
    _checkRateLimit();
  }

  Future<void> _checkRateLimit() async {
    final limitError = await AccessRequestRateLimiter.checkRateLimit();
    if (mounted) {
      setState(() => _rateLimitError = limitError);
    }
  }

  Future<void> _checkSilentSignIn() async {
    final account = await GoogleDriveService.signInSilently();
    if (account != null && mounted) {
      ref.read(userEmailProvider.notifier).setEmail(account.email);
      _nameController.text = account.displayName ?? '';
      _emailController.text = account.email;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _googleSignIn() async {
    setState(() => _isGoogleSigningIn = true);
    try {
      final account = await GoogleDriveService.signIn();
      if (account != null) {
        await ref.read(userEmailProvider.notifier).setEmail(account.email);
        setState(() {
          _nameController.text = account.displayName ?? '';
          _emailController.text = account.email;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sign-in failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGoogleSigningIn = false);
    }
  }

  String get _appId => widget.app?.id ?? 'cash-book';
  String get _appName => widget.app?.name ?? 'All Beta Apps';

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    try {
      final name = _nameController.text.trim();
      final email = _emailController.text.trim();
      
      await ref.read(appConfigRepositoryProvider).submitAccessRequest(
            name,
            email,
            _appId,
            _appName,
          );
      await ref.read(userEmailProvider.notifier).setEmail(email);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Access request submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final errorMsg = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch $urlString';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open Play Store: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userEmail = ref.watch(userEmailProvider);
    final requestAsync = ref.watch(appAccessRequestStreamProvider(_appId));
    final accessGrantedAsync = ref.watch(isSpecificAppAccessGrantedProvider(_appId));

    final bool isApproved = accessGrantedAsync.value ?? false;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                if (widget.app != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      widget.app!.imageUrl,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 48,
                        height: 48,
                        color: theme.colorScheme.primaryContainer,
                        child: Icon(Icons.apps_rounded, color: theme.colorScheme.primary),
                      ),
                    ),
                  )
                else
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.science_rounded, color: theme.colorScheme.primary, size: 26),
                  ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _appName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Beta Testing Access',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.orange[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'This application is currently in Close Testing mode. Only approved beta testing accounts are allowed to access and install it.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),

            // If approved but not editing, show direct Play Store Link!
            if (isApproved && !_isEditingAfterApproval) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Colors.green, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      'Access Granted!',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.green[800],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Your email ($userEmail) is approved. You can now download the app from Google Play Store.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                        ),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('Download on Play Store'),
                        onPressed: () => _launchUrl(widget.app?.playStoreUrl ?? ''),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                          side: const BorderSide(color: Colors.green),
                        ),
                        icon: const Icon(Icons.edit_rounded),
                        label: const Text('Change Request Details'),
                        onPressed: () {
                          setState(() => _isEditingAfterApproval = true);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ] else if (isApproved && _isEditingAfterApproval) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.edit_rounded, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Update Your Information',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildRequestForm(userEmail),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () {
                  setState(() => _isEditingAfterApproval = false);
                },
                icon: const Icon(Icons.close_rounded, size: 16),
                label: const Text('Cancel'),
              ),
              const SizedBox(height: 24),
            ] else if (userEmail.isNotEmpty) ...[
              requestAsync.when(
                data: (request) {
                  if (request == null) {
                    return _buildRequestForm(userEmail);
                  }
                  return _buildRequestStatusCard(request);
                },
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (e, _) => Text(
                  'Failed to load request: $e',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
              const SizedBox(height: 24),
            ] else ...[
              // Google Sign In
              if (GoogleDriveService.currentUser == null) ...[
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    foregroundColor: theme.colorScheme.onSurface,
                  ),
                  onPressed: _isGoogleSigningIn ? null : _googleSignIn,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_isGoogleSigningIn)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        Container(
                          width: 22,
                          height: 22,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                          ),
                          child: const Center(
                            child: Text(
                              'G',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF4285F4),
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(width: 12),
                      const Flexible(
                        child: Text(
                          'Sign in with Google to Check Access',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'OR REQUEST ACCESS',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              if (_rateLimitError != null)
                _buildRateLimitExceededCard()
              else
                _buildRequestForm(''),
            ],

            if (userEmail.isNotEmpty && !isApproved) ...[
              TextButton.icon(
                onPressed: () {
                  ref.read(userEmailProvider.notifier).clearEmail();
                  GoogleDriveService.signOut();
                },
                icon: const Icon(Icons.logout_rounded, size: 16),
                label: const Text('Sign out / Clear Email'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRequestStatusCard(AccessRequestModel request) {
    final theme = Theme.of(context);
    Color statusColor = Colors.orange;
    IconData statusIcon = Icons.pending_actions_rounded;
    String statusTitle = 'Request Pending';

    if (request.isApproved) {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle_rounded;
      statusTitle = 'Access Approved';
    } else if (request.isRejected) {
      statusColor = Colors.red;
      statusIcon = Icons.cancel_rounded;
      statusTitle = 'Access Declined';
    }

    return Card(
      color: statusColor.withOpacity(0.08),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: statusColor.withOpacity(0.4)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(statusIcon, color: statusColor),
                const SizedBox(width: 8),
                Text(
                  statusTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Email: ${request.email}',
              style: theme.textTheme.bodySmall,
            ),
            if (request.adminMessage.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Admin Message:',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      request.adminMessage,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
            if (request.isRejected) ...[
              const SizedBox(height: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  minimumSize: const Size.fromHeight(40),
                ),
                child: const Text('Re-submit Request'),
                onPressed: () {
                  // Pre-populate and let them re-submit
                  _nameController.text = request.name;
                  _emailController.text = request.email;
                  ref.read(userEmailProvider.notifier).clearEmail();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRequestForm(String prefilledEmail) {
    final theme = Theme.of(context);
    if (prefilledEmail.isNotEmpty && _emailController.text.isEmpty) {
      _emailController.text = prefilledEmail;
    }

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Your Name',
              prefixIcon: Icon(Icons.person_outline_rounded),
              border: OutlineInputBorder(),
            ),
            validator: (value) =>
                value == null || value.trim().isEmpty ? 'Please enter your name' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email Address',
              prefixIcon: Icon(Icons.email_outlined),
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your email';
              }
              if (!value.contains('@')) {
                return 'Please enter a valid email';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
            ),
            icon: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send_rounded),
            label: const Text('Submit Request'),
            onPressed: _isSubmitting ? null : _submitRequest,
          ),
        ],
      ),
    );
  }

  Widget _buildRateLimitExceededCard() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.amber.shade500.withValues(alpha: isDark ? 0.15 : 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.amber.shade700.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.hourglass_top_rounded,
            size: 44,
            color: Colors.amber.shade800,
          ),
          const SizedBox(height: 12),
          Text(
            'Daily Request Limit Reached',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.amber.shade300 : Colors.amber.shade900,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Aap 24 ghanton mein 3 requests submit kar chuke hain. Aapka daily limit pura ho chuka hai. Baraye meharbani 24 ghanton ke baad dubara koshish karein.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
