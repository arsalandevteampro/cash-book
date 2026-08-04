import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/app_model.dart';
import '../../data/repositories/more_apps_repository_impl.dart';
import '../../domain/more_apps_repository.dart';

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final moreAppsRepositoryProvider = Provider<MoreAppsRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return MoreAppsRepositoryImpl(firestore);
});

final activeAppsStreamProvider = StreamProvider<List<AppModel>>((ref) {
  final repository = ref.watch(moreAppsRepositoryProvider);
  return repository.getActiveApps();
});
