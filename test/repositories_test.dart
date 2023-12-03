import 'dart:async';

import 'package:faker/faker.dart';
import 'package:parousia/models/models.dart';
import 'package:parousia/repositories/repositories.dart';
import 'package:parousia/util/util.dart';
import 'package:supabase/supabase.dart';
import 'package:test/test.dart';

final SupabaseConfig config =
    SupabaseConfig.fromPath('supabase/config/localhost.json');

SupabaseClient supabaseAnonClient() =>
    SupabaseClient(config.apiUrl, config.anonKey);

SupabaseClient supabaseAdminClient() =>
    SupabaseClient(config.apiUrl, config.serviceRoleKey);

/// Singleton instance of a Supabase client with admin rights
/// (it's not very useful to have many as there's no auth user)
final supabaseAdmin = supabaseAdminClient();

/// Create a new fake user in Supabase.
/// This replaces the current authenticated user in the provided [supabase].
Future<AuthResponse> signUpWithNewUser(SupabaseClient supabase) =>
    supabase.auth.signUp(password: 'password', email: faker.internet.email());

typedef RunWithUserCallback<T> = FutureOr<T> Function(
    SupabaseClient supabase, AuthResponse user);

/// Run a callback with a new fake user, and keep it for future reference.
Future<(AuthResponse, T)> runWithUser<T>(
    RunWithUserCallback<T> callback) async {
  final supabase = supabaseAnonClient();
  final user = await signUpWithNewUser(supabase);
  final result = await callback(supabase, user);
  return (user, result);
}

/// Run a closure with a temporary user created just for this and then deleted.
Future<T> runWithTemporaryUser<T>(RunWithUserCallback<T> callback) async {
  final (user, result) = await runWithUser(callback);
  await supabaseAdmin.auth.admin.deleteUser(user.user!.id);
  return result;
}

Group fakeGroup() => Group(
      displayName: faker.conference.name(),
      description: faker.lorem.sentences(3).join(' '),
      picture: faker.image.image(height: 128, width: 128),
      id: 0,
    );

void main() {
  group('profiles', () {
    test(
        'users should be able to sign up and delete their profile',
        () => runWithTemporaryUser(
            (supabase, user) => expect(user.user, isNotNull)));

    test(
      'users should be able to get and update their profile',
      () => runWithTemporaryUser((supabase, user) async {
        final profilesRepository = ProfilesRepository(supabase: supabase);

        final id = user.user!.id;
        final profile = await profilesRepository.getProfileById(id);

        final displayName = faker.person.name();
        final pictureUrl = faker.image.image(height: 128, width: 128);

        await profilesRepository.updateProfile(
          id: id,
          displayName: displayName,
          pictureUrl: pictureUrl,
        );
        final updatedProfile = await profilesRepository.getProfileById(id);

        expect(
            updatedProfile,
            allOf([
              isNotNull,
              isNot(profile),
            ]));

        expect(updatedProfile.displayName, equals(displayName));
        expect(updatedProfile.picture, equals(pictureUrl));
      }),
    );
  });

  group('groups', () {
    test(
      'all users should be able to create groups',
      () => runWithTemporaryUser(
        (supabase, user) async {
          final groupsRepository = GroupsRepository(supabase: supabase);

          final newGroup = await groupsRepository.createGroup(fakeGroup());

          expect(newGroup, isNotNull);

          // Another user should not see the group if they are not a member
          await runWithTemporaryUser((supabase, user) async {
            final secondUserGroupsRepository =
                GroupsRepository(supabase: supabase);
            try {
              await secondUserGroupsRepository.getGroupById(newGroup.id);
              fail("Should not be able to get group without being a member");
            } catch (e) {
              expect(e, isA<PostgrestException>());
            }
          });
        },
      ),
    );

    test(
      'admins should be able to see all the groups they created',
      () => runWithTemporaryUser((supabase, user) async {
        final groupsRepository = GroupsRepository(supabase: supabase);
        const groupsCount = 5;
        final createdGroups = List.generate(groupsCount, (_) => fakeGroup());

        await Future.wait(
            createdGroups.map((g) => groupsRepository.createGroup(g)));

        final userGroups = await groupsRepository.getUserGroups();

        expect(userGroups, hasLength(groupsCount));
        // ? How to match just user-configured properties?
        // expect(userGroups, unorderedEquals(createdGroups));
      }),
    );

    test(
      'admins can edit their groups',
      () => runWithTemporaryUser((supabase, user) async {
        final groupsRepository = GroupsRepository(supabase: supabase);
        final group = await groupsRepository.createGroup(fakeGroup());

        const newName = 'A new group name';
        final updatedGroup = await groupsRepository
            .updateGroup(group.copyWith(displayName: newName));

        expect(updatedGroup.displayName, equals(newName));
      }),
    );
  });

  group('members', () {
    test(
      'admins can add guests to groups',
      () => runWithTemporaryUser((supabase, user) async {
        final groupsRepository = GroupsRepository(supabase: supabase);
        final membersRepository = MembersRepository(supabase: supabase);
        final group = await groupsRepository.createGroup(fakeGroup());

        await membersRepository.addMemberToGroup(group.id,
            displayName: 'A guest');
      }),
    );

    test(
      'admins can add other users to groups',
      () => runWithTemporaryUser((supabase, user) async {
        final groupsRepository = GroupsRepository(supabase: supabase);
        final membersRepository = MembersRepository(supabase: supabase);
        final group = await groupsRepository.createGroup(fakeGroup());

        await runWithTemporaryUser((_, user2) => membersRepository
            .addMemberToGroup(group.id, profileId: user2.user!.id));
      }),
    );

    test(
      'admins can manage group members',
      () => runWithTemporaryUser((supabase, user) async {
        final groupsRepository = GroupsRepository(supabase: supabase);
        final membersRepository = MembersRepository(supabase: supabase);
        final group = await groupsRepository.createGroup(fakeGroup());

        final guest = await membersRepository.addMemberToGroup(group.id,
            displayName: 'A guest');

        final updatedGuest = await membersRepository.updateMember(
            memberId: guest.id, displayNameOverride: 'A guest with a name');

        await membersRepository.removeMember(updatedGuest.id);
      }),
    );
  });

  group('invites', () {
    test(
      'admins can invite new members to groups',
      () => runWithTemporaryUser((supabase, user) async {
        final groupsRepository = GroupsRepository(supabase: supabase);
        final membersRepository = MembersRepository(supabase: supabase);
        final invitesRepository = InvitesRepository(supabase: supabase);
        final group = await groupsRepository.createGroup(fakeGroup());

        final member = await membersRepository.addMemberToGroup(group.id,
            displayName: 'Invited member');

        final invite = await invitesRepository.inviteMember(
            member.id, InviteMethods.email, faker.internet.email());

        expect(invite, isNotNull);
      }),
    );
  });
}
