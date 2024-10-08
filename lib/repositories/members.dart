import 'package:parousia/models/models.dart';

import 'const.dart';
import 'supabase.dart';

class MembersRepository extends SupabaseRepository with Postgrest {
  const MembersRepository({required super.supabase})
      : super(tableName: Tables.members);

  Future<Member> addMemberToGroup(int groupId,
      {String? displayName, String? profileId}) async {
    if ((displayName == null || displayName.isEmpty) &&
        (profileId == null || profileId.isEmpty)) {
      throw ArgumentError(
          'Either displayName or profileId must be provided to addMemberToGroup');
    }

    return table()
        .insert({
          'group_id': groupId,
          'profile_id': profileId,
          'display_name_override': displayName,
        })
        .select()
        .single()
        .withConverter((data) => Member.fromJson(data));
  }

  Future<Member> updateMember(
      {required int memberId, required String? displayNameOverride}) async {
    return table()
        .update({
          'display_name_override': displayNameOverride,
        })
        .eq('id', memberId)
        .select()
        .single()
        .withConverter(Member.fromJson);
  }

  Future<void> removeMember(int memberId) async {
    return table().delete().eq('id', memberId);
  }
}
