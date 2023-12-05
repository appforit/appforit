import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:parousia/go_router_builder.dart';
import 'package:parousia/models/models.dart';
import 'package:parousia/presentation/presentation.dart';
import 'package:parousia/screens/screens.dart';

typedef NewGroupReturnCallback = void Function(NewGroupReturn);

class HomeScreen extends StatelessWidget {
  final Profile? profile;
  final Iterable<Group>? groups;
  final bool loading;
  final NewGroupReturnCallback? onNewGroup;

  const HomeScreen({
    super.key,
    this.loading = false,
    this.profile,
    this.groups,
    this.onNewGroup,
  });

  ImageProvider? _profilePicture() {
    if (profile?.picture != null) {
      return NetworkImage(profile!.picture!);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    final nothingToShow = groups == null || groups!.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appName),
        bottom: loading
            ? PreferredSize(
                preferredSize: Size(MediaQuery.of(context).size.width, 0),
                child: const LinearProgressIndicator())
            : null,
        actions: [
          ProfilePicture(
            onPressed: () => ProfileRoute().push(context),
            image: _profilePicture(),
            name: profile?.displayName,
          ),
        ],
      ),
      body: nothingToShow ? const HomeEmptyState() : GroupsList(groups: groups),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => NewGroupRoute()
            .push<NewGroupReturn>(context)
            .then((value) => value != null ? onNewGroup?.call(value) : null),
        label: Text(l10n.createOrJoinGroup),
        icon: const Icon(Icons.group_add_outlined),
      ),
    );
  }
}
