import 'package:flutter/foundation.dart'; // ignore: unused_import
import 'package:freezed_annotation/freezed_annotation.dart';

import 'enum.dart';

part 'member.freezed.dart';
part 'member.g.dart';

@freezed
sealed class Member with _$Member {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory Member({
    required int id,
    required int groupId,
    required GroupRoles role,
    String? profileId,
    String? displayNameOverride,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _Member;

  factory Member.fromJson(Map<String, dynamic> json) => _$MemberFromJson(json);
}
