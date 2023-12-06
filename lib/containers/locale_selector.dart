import 'package:flutter/foundation.dart'; // ignore: unused_import
import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:parousia/actions/actions.dart';
import 'package:parousia/screens/locale.dart';
import 'package:parousia/selectors/selectors.dart';
import 'package:parousia/state/state.dart';
import 'package:redux/redux.dart';

part 'locale_selector.freezed.dart';

class LocaleSelector extends StatelessWidget {
  const LocaleSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return StoreConnector<RootState, _ViewModel>(
      distinct: true,
      converter: _ViewModel.fromStore,
      builder: (context, vm) => LocaleScreen(
        selectedLocale: vm.locale,
        changeLocale: vm.changeLocale,
      ),
    );
  }
}

@freezed
sealed class _ViewModel with _$ViewModel {
  const factory _ViewModel({
    Locale? locale,
    required void Function(Locale?) changeLocale,
  }) = __ViewModel;

  factory _ViewModel.fromStore(Store<RootState> store) {
    return _ViewModel(
      locale: localeSelector(store.state),
      changeLocale: (Locale? locale) =>
          store.dispatch(ChangeLocaleAction(locale)),
    );
  }
}
