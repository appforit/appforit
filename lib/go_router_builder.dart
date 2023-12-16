import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:parousia/presentation/presentation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'go_router_builder.g.dart';

@TypedGoRoute<HomeScreenRoute>(
  path: '/',
  routes: [
    TypedGoRoute<AuthRoute>(path: 'auth'),
    TypedGoRoute<ProfileRoute>(path: 'profile'),
    TypedGoRoute<SelectContactsRoute>(path: 'select-contacts'),
    TypedGoRoute<GroupCreateRoute>(path: 'group-create'),
    TypedGoRoute<GroupDetailsRoute>(
      path: 'groups/:groupId',
      routes: [
        TypedGoRoute<GroupManageRoute>(path: 'manage'),
        // TODO Should be at root level?
        TypedGoRoute<GroupScheduleRoute>(path: 'schedule'),
      ],
    ),
    TypedGoRoute<SettingsRoute>(
      path: 'settings',
      routes: [
        TypedGoRoute<LocaleRoute>(path: 'locale'),
      ],
    ),
  ],
)
@immutable
class HomeScreenRoute extends GoRouteData with AuthenticationGuard {
  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const HomeContainer();
}

@immutable
class AuthRoute extends GoRouteData {
  @override
  Widget build(BuildContext context, GoRouterState state) => const AuthScreen();
}

@immutable
class SettingsRoute extends GoRouteData with AuthenticationGuard {
  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const SettingsScreen();
}

@immutable
class LocaleRoute extends GoRouteData with AuthenticationGuard {
  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const LocaleContainer();
}

@immutable
class ProfileRoute extends GoRouteData with AuthenticationGuard {
  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const ProfileContainer();
}

@immutable
class GroupCreateRoute extends GoRouteData with AuthenticationGuard {
  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const GroupCreateScreen();
}

@immutable
class GroupDetailsRoute extends GoRouteData with AuthenticationGuard {
  final String groupId;

  const GroupDetailsRoute({required this.groupId});

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      GroupDetailsContainer(groupId: groupId);
}

@immutable
class GroupManageRoute extends GoRouteData with AuthenticationGuard {
  // TODO Should be for admins only

  final String groupId;

  const GroupManageRoute({required this.groupId});

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      GroupManageContainer(groupId: groupId);
}

@immutable
class GroupScheduleRoute extends GoRouteData with AuthenticationGuard {
  final String groupId;

  const GroupScheduleRoute({required this.groupId});

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const ScheduleScreen();
}

@immutable
class SelectContactsRoute extends GoRouteData with AuthenticationGuard {
  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const SelectContactsScreen();
}

// Check if a user exists in the Supabase client
_isAuthenticated() => Supabase.instance.client.auth.currentUser != null;

/// Routes that require authentication should use this mixin
mixin AuthenticationGuard on GoRouteData {
  @override
  redirect(BuildContext context, GoRouterState state) =>
      _isAuthenticated() ? null : AuthRoute().location;
// TODO(borgoat): This redirect keeps the previous route in the stack,
//                It should replace the current route, to prevent the user
//                from navigating back to the home page while signed out.
//                Investigate whether to use a "splashscreen" route instead.
}
