import '../data/models/app_model.dart';

abstract class MoreAppsRepository {
  Stream<List<AppModel>> getActiveApps();
}
