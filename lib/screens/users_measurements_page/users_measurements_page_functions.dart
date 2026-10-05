import '../../services/local_database/unified_database_service.dart';

class UsersMeasurementsPageFunctions {
  static Stream<List<Map<String, dynamic>>> streamPeople() async* {
    while (true) {
      try {
        final people = await UnifiedDatabaseService.instance.getPeople();
        yield people;
        await Future.delayed(const Duration(seconds: 5));
      } catch (e) {
        print('Error en stream de personas: $e');
        yield [];
        await Future.delayed(const Duration(seconds: 5));
      }
    }
  }
}
