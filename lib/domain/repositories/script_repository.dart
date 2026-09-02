import '../models/user_script.dart';

abstract interface class ScriptRepository {
  Future<List<UserScript>> all();
  Future<UserScript?> byId(String id);
  Future<void> upsert(UserScript script);
  Future<void> delete(String id);
}
