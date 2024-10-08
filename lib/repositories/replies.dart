import 'package:parousia/models/models.dart';
import 'package:parousia/util/util.dart';

import 'const.dart';
import 'supabase.dart';

class RepliesRepository extends SupabaseRepository with Postgrest {
  const RepliesRepository({required super.supabase})
      : super(tableName: Tables.replies);

  Future<Iterable<Reply>> getRepliesForDay(int groupId, DateTime day) async {
    return getRepliesForDateRange(groupId, day.toUtc().getDayRange());
  }

  Future<Iterable<Reply>> getRepliesForDateRange(
      int groupId, DateTimeRange dateRange) async {
    return table()
        .select('*,members!inner(*)')
        .eq('members.group_id', groupId)
        .gte('event_date', dateRange.start)
        .lt('event_date', dateRange.end)
        .withConverter((data) => data.map(Reply.fromJson));
  }

  Future<Reply> createReply(Reply reply) async {
    return table()
        .upsert({
          'schedule_id': reply.scheduleId,
          'member_id': reply.memberId,
          'event_date': reply.eventDate.toIso8601String(),
          'selected_option': reply.selectedOption.name,
        }, onConflict: 'member_id, schedule_id, event_date')
        .select()
        .single()
        .withConverter((data) => Reply.fromJson(data));
  }

  Future<void> deleteReply({
    required int memberId,
    required int scheduleId,
    required DateTime eventDate,
  }) async {
    return table()
        .delete()
        .eq('member_id', memberId)
        .eq('schedule_id', scheduleId)
        .eq('event_date', eventDate.toIso8601String());
  }
}
