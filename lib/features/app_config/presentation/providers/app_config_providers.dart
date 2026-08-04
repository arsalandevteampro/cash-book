import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/access_request_model.dart';
import '../../data/repositories/app_config_repository_impl.dart';
import '../../domain/app_config_repository.dart';
import '../../../more_apps/presentation/providers/more_apps_providers.dart';

final appConfigRepositoryProvider = Provider<AppConfigRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return AppConfigRepositoryImpl(firestore);
});

final appModeStreamProvider = StreamProvider<String>((ref) {
  return ref.watch(appConfigRepositoryProvider).watchAppMode();
});

final testingEmailsStreamProvider = StreamProvider<List<String>>((ref) {
  return ref.watch(appConfigRepositoryProvider).watchTestingEmails();
});

// A StateNotifier to store and persist the user email used for checking testing status
class UserEmailNotifier extends StateNotifier<String> {
  UserEmailNotifier() : super('') {
    _loadPersistedEmail();
  }

  Future<void> _loadPersistedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString('tester_email') ?? '';
  }

  Future<void> setEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    final cleanEmail = email.toLowerCase().trim();
    await prefs.setString('tester_email', cleanEmail);
    state = cleanEmail;
  }

  Future<void> clearEmail() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('tester_email');
    state = '';
  }
}

final userEmailProvider = StateNotifierProvider<UserEmailNotifier, String>((ref) {
  return UserEmailNotifier();
});

// Watch the access request for the current user's email
final userAccessRequestStreamProvider = StreamProvider<AccessRequestModel?>((ref) {
  final email = ref.watch(userEmailProvider);
  if (email.isEmpty) return Stream.value(null);
  
  final repo = ref.watch(appConfigRepositoryProvider);
  return repo.watchRequestByEmailAndApp(email, 'cash-book');
});

// Watch the access request for the current user's email and a specific app ID
final appAccessRequestStreamProvider = StreamProvider.family<AccessRequestModel?, String>((ref, appId) {
  final email = ref.watch(userEmailProvider);
  if (email.isEmpty) return Stream.value(null);
  
  final repo = ref.watch(appConfigRepositoryProvider);
  return repo.watchRequestByEmailAndApp(email, appId);
});

// Determine if the user is authorized to open the app
final isAccessGrantedProvider = Provider<AsyncValue<bool>>((ref) {
  final modeAsync = ref.watch(appModeStreamProvider);
  final emailsAsync = ref.watch(testingEmailsStreamProvider);
  final userEmail = ref.watch(userEmailProvider);

  return modeAsync.when(
    data: (mode) {
      if (mode == 'production') {
        return const AsyncValue.data(true);
      }
      
      // In testing mode:
      if (userEmail.isEmpty) {
        return const AsyncValue.data(false);
      }

      return emailsAsync.when(
        data: (emails) {
          final isApproved = emails.contains(userEmail.toLowerCase().trim());
          return AsyncValue.data(isApproved);
        },
        loading: () => const AsyncValue.loading(),
        error: (err, stack) => AsyncValue.error(err, stack),
      );
    },
    loading: () => const AsyncValue.loading(),
    error: (err, stack) => AsyncValue.error(err, stack),
  );
});

// Determine if the user has access to a specific testing app
final isSpecificAppAccessGrantedProvider = Provider.family<AsyncValue<bool>, String>((ref, appId) {
  final emailsAsync = ref.watch(testingEmailsStreamProvider);
  final userEmail = ref.watch(userEmailProvider);

  if (userEmail.isEmpty) {
    return const AsyncValue.data(false);
  }

  return emailsAsync.when(
    data: (emails) {
      final isApproved = emails.contains(userEmail.toLowerCase().trim());
      return AsyncValue.data(isApproved);
    },
    loading: () => const AsyncValue.loading(),
    error: (err, stack) => AsyncValue.error(err, stack),
  );
});
