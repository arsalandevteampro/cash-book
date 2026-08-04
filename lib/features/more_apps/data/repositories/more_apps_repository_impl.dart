import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/more_apps_repository.dart';
import '../models/app_model.dart';

class MoreAppsRepositoryImpl implements MoreAppsRepository {
  final FirebaseFirestore _firestore;

  MoreAppsRepositoryImpl(this._firestore);

  @override
  Stream<List<AppModel>> getActiveApps() {
    // Using only orderBy (no compound where+orderBy) to avoid requiring
    // a composite Firestore index. Filtering active==true is done in Dart.
    return _firestore
        .collection('apps')
        .orderBy('priority', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => AppModel.fromMap(doc.data(), doc.id))
          .where((app) => app.active)
          .toList();
    });
  }
}
