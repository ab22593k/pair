import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:localsend_app/features/send/provider/selected_sending_files_provider.dart';
import 'package:localsend_app/pages/home_page.dart';
import 'package:localsend_app/util/native/cross_file_converters.dart';
import 'package:refena_flutter/refena_flutter.dart';

class HomePageVm {
  final PageController controller;
  final HomeTab currentTab;
  final void Function(HomeTab) changeTab;

  HomePageVm({
    required this.controller,
    required this.currentTab,
    required this.changeTab,
  });
}

final homePageControllerProvider = ReduxProvider<HomePageController, HomePageVm>(
  (ref) => HomePageController(
    selectedSendingFilesService: ref.notifier(selectedSendingFilesProvider),
  ),
);

class HomePageController extends ReduxNotifier<HomePageVm> {
  final SelectedSendingFilesNotifier selectedSendingFilesService;

  HomePageController({
    required this.selectedSendingFilesService,
  });

  @override
  HomePageVm init() {
    return HomePageVm(
      controller: PageController(),
      currentTab: HomeTab.receive,
      changeTab: (tab) => redux.dispatch(ChangeTabAction(tab)),
    );
  }
}

class ChangeTabAction extends ReduxAction<HomePageController, HomePageVm> {
  final HomeTab tab;

  ChangeTabAction(this.tab);

  @override
  HomePageVm reduce() {
    state.controller.jumpToPage(tab.index);
    return HomePageVm(
      controller: state.controller,
      currentTab: tab,
      changeTab: state.changeTab,
    );
  }
}

class HandleFileDropAction extends AsyncReduxAction<HomePageController, HomePageVm> {
  final List<XFile> files;

  HandleFileDropAction(this.files);

  @override
  Future<HomePageVm> reduce() async {
    if (files.length == 1 && Directory(files.first.path).existsSync()) {
      await external(notifier.selectedSendingFilesService).dispatchAsync(AddDirectoryAction(files.first.path));
    } else {
      await external(notifier.selectedSendingFilesService).dispatchAsync(
        AddFilesAction(
          files: files,
          converter: CrossFileConverters.convertXFile,
        ),
      );
    }
    dispatch(ChangeTabAction(HomeTab.send));
    return state;
  }
}
