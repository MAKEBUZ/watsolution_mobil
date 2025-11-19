import 'package:supabase_flutter/supabase_flutter.dart';

class UsersMeasurementsPageFunctions {
  static Stream<List<Map<String, dynamic>>> streamPeople() {
    final client = Supabase.instance.client;
    return client.from('people').stream(primaryKey: ['id']).order('full_name');
  }

  static Future<int> createAddress({required String neighborhood, String? street, String? houseNumber, required String city}) async {
    final client = Supabase.instance.client;
    final addrInsert = await client
        .from('addresses')
        .insert({
          'neighborhood': neighborhood,
          'street': street?.isEmpty == true ? null : street,
          'house_number': houseNumber?.isEmpty == true ? null : houseNumber,
          'city': city,
        })
        .select('id')
        .single();
    return addrInsert['id'] as int;
  }

  static Future<void> createUser({required String fullName, required String documentNumber, String? phone, String? email, required int addressId}) async {
    final client = Supabase.instance.client;
    await client.from('people').insert({
      'full_name': fullName,
      'document_number': documentNumber,
      'phone': phone?.isEmpty == true ? null : phone,
      'email': email?.isEmpty == true ? null : email,
      'status': 'active',
      'address_id': addressId,
    });
  }
}
