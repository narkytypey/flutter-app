import '../models/filter_list.dart';

abstract interface class FilterListRepository {
  Future<List<FilterList>> all();
  Future<void> setEnabled(String id, bool enabled);
}
