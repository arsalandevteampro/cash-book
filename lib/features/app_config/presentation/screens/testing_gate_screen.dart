import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../services/google_drive_service.dart';
import '../../data/models/access_request_model.dart';
import '../providers/app_config_providers.dart';

class TestingGateScreen extends ConsumerStatefulWidget {
  final Widget child; // The screen to show if access is granted (e.g. HomeScreen/Splash)
  const TestingGateScreen({super.key, required this.child});

  @override
  ConsumerState<TestingGateScreen> createState() => _TestingGateScreenState();
}

class _TestingGateScreenState extends ConsumerState<TestingGateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  bool _isSubmitting = false;
  bool _isGoogleSigningIn = false;
  bool _isEditingAfterApproval = false;

  @override
  void initState() {
    super.initState();
    _checkSilentSignIn();
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

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    try {
      final name = _nameController.text.trim();
      final email = _emailController.text.trim();
      
      await ref.read(appConfigRepositoryProvider).submitAccessRequest(
            name,
            email,
            'cash-book',
            'Cash Book',
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accessGrantedAsync = ref.watch(isAccessGrantedProvider);

    return accessGrantedAsync.when(
      data: (granted) {
        if (granted) {
          return widget.child;
        }
        return _buildGateUI();
      },
      loading: () => const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      ),
      error: (e, _) => Scaffold(
        body: Center(
          child: Text('Error checking access status: $e'),
        ),
      ),
    );
  }

  Widget _buildGateUI() {
    final theme = Theme.of(context);
    final userEmail = ref.watch(userEmailProvider);
    final requestAsync = ref.watch(userAccessRequestStreamProvider);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.science_rounded,
                  size: 80,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  'Beta Testing Mode',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'This app is currently in Close Testing mode. Only approved beta testing accounts are allowed to log in and use it.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 32),

                // Request status card or edit form
                if (userEmail.isNotEmpty) ...[
                  if (_isEditingAfterApproval) ...[
                    Container(
                      padding: const EdgeInsets.all(20),
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
                          const SizedBox(height: 16),
                          _buildRequestForm(),
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
                  ] else ...[
                    requestAsync.when(
                      data: (request) {
                        if (request == null) {
                          return const SizedBox.shrink();
                        }
                        return _buildRequestStatusCard(request);
                      },
                      loading: () => const Center(
                        child: Padding(
                          padding: EdgeInsets.all(8.0),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                      error: (e, _) => Text(
                        'Failed to load request: $e',
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                ],

                // Google Sign In option
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
                        const Text('Sign in with Google to Check Access'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
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
                  const SizedBox(height: 20),
                ],

                // Request Form
                _buildRequestForm(),
                
                if (userEmail.isNotEmpty) ...[
                  const SizedBox(height: 16),
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
            if (request.isApproved) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.edit_rounded, size: 16),
                label: const Text('Change Request Details'),
                onPressed: () {
                  setState(() => _isEditingAfterApproval = true);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRequestForm() {
    final theme = Theme.of(context);
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
}
