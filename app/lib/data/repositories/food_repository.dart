
import '../../core/services/api_client.dart';
import '../../core/utils/formatters.dart';
import '../models/tracking.dart';

abstract interface class FoodRepository {
  Future<FoodEntry> add(String patientId, {required String name, required String quantity, required MealType meal, required DateTime eatenAt});

  /// Creates a new revision; the previous entry stays in history.
  Future<FoodEntry> edit(String entryId, {required String name, required String quantity, required MealType meal, required DateTime eatenAt});
  Future<List<FoodEntry>> list(String patientId, {DateTime? start, DateTime? end});
}

class ApiFoodRepository implements FoodRepository {
  ApiFoodRepository(this._api);
  final ApiClient _api;

  Map<String, dynamic> _body(String name, String quantity, MealType meal, DateTime eatenAt) =>
      {'food_name': name.trim(), 'quantity': quantity.trim(), 'meal_type': meal.name, 'eaten_at': eatenAt.toUtc().toIso8601String()};

  @override
  Future<FoodEntry> add(String patientId, {required String name, required String quantity, required MealType meal, required DateTime eatenAt}) async =>
      FoodEntry.fromJson(await _api.post('/patients/$patientId/food', body: _body(name, quantity, meal, eatenAt)));

  @override
  Future<FoodEntry> edit(String entryId, {required String name, required String quantity, required MealType meal, required DateTime eatenAt}) async =>
      FoodEntry.fromJson(await _api.put('/food/$entryId', body: _body(name, quantity, meal, eatenAt)));

  @override
  Future<List<FoodEntry>> list(String patientId, {DateTime? start, DateTime? end}) async {
    final r = await _api.get('/patients/$patientId/food', query: {'start': start == null ? null : Fmt.isoDate(start), 'end': end == null ? null : Fmt.isoDate(end)});
    return [for (final f in r['items'] as List) FoodEntry.fromJson(f as Json)];
  }
}
