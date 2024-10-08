import 'package:parousia/models/models.dart';

import 'const.dart';
import 'supabase.dart';

class ProfilesRepository extends SupabaseRepository with Postgrest {
  const ProfilesRepository({required super.supabase})
      : super(tableName: Tables.profiles);

  Future<Profile> getProfileById(String id) async {
    return table()
        .select()
        .eq('id', id)
        .single()
        .withConverter(Profile.fromJson);
  }

  Future<void> updateProfile({
    required String id,
    String? displayName,
    String? pictureUrl,
  }) async {
    return table().update({
      if (displayName != null) 'display_name': displayName,
      if (pictureUrl != null) 'picture': pictureUrl,
    }).eq('id', id);
  }
}
