import 'dart:convert';

import 'package:common/model/file_type.dart';
import 'package:test/test.dart';
import 'package:localsend_app/features/send/provider/selected_sending_files_provider.dart';
import 'package:localsend_app/model/cross_file.dart';
import 'package:refena_flutter/refena_flutter.dart';

void main() {
  // ---------------------------------------------------------------------------
  // AddMessageAction
  // ---------------------------------------------------------------------------
  group('AddMessageAction', () {
    test('adds a text file with the encoded message', () {
      final notifier = ReduxNotifier.test(
        redux: SelectedSendingFilesNotifier(),
      );

      expect(notifier.state, isEmpty);

      notifier.dispatch(AddMessageAction(message: 'hello'));

      expect(notifier.state.length, 1);
      final file = notifier.state.first;
      expect(file.fileType, FileType.text);
      expect(utf8.decode(file.bytes!), 'hello');
      expect(file.size, utf8.encode('hello').length);
    });

    test('inserts at a given index', () {
      final existing = _makeTextFile('first', 'First');
      final notifier = ReduxNotifier.test(
        redux: SelectedSendingFilesNotifier(),
        initialState: [existing],
      );

      notifier.dispatch(AddMessageAction(message: 'second', index: 0));

      expect(notifier.state.length, 2);
      expect(utf8.decode(notifier.state[0].bytes!), 'second');
      expect(utf8.decode(notifier.state[1].bytes!), 'First');
    });
  });

  // ---------------------------------------------------------------------------
  // UpdateMessageAction — regression test for the stale-state bug
  // ---------------------------------------------------------------------------
  group('UpdateMessageAction', () {
    test('returns the UPDATED state, not the pre-dispatch state', () {
      final original = _makeTextFile('a-uuid.txt', 'original');
      final notifier = ReduxNotifier.test(
        redux: SelectedSendingFilesNotifier(),
        initialState: [original],
      );

      notifier.dispatch(
        UpdateMessageAction(message: 'updated', index: 0),
      );

      // The state AFTER the action must reflect the updated message.
      expect(notifier.state.length, 1);
      final updated = notifier.state.first;
      expect(utf8.decode(updated.bytes!), 'updated', reason: 'UpdateMessageAction must return the new state, not the stale pre-dispatch state');
      expect(updated.size, utf8.encode('updated').length);
      expect(updated.fileType, FileType.text);
    });

    test('preserves surrounding files when updating at a given index', () {
      final before = _makeTextFile('b.txt', 'before');
      final target = _makeTextFile('t.txt', 'target');
      final after = _makeTextFile('a.txt', 'after');

      final notifier = ReduxNotifier.test(
        redux: SelectedSendingFilesNotifier(),
        initialState: [before, target, after],
      );

      notifier.dispatch(
        UpdateMessageAction(message: 'changed', index: 1),
      );

      expect(notifier.state.length, 3);
      expect(utf8.decode(notifier.state[0].bytes!), 'before');
      expect(utf8.decode(notifier.state[1].bytes!), 'changed');
      expect(utf8.decode(notifier.state[2].bytes!), 'after');
    });
  });

  // ---------------------------------------------------------------------------
  // RemoveSelectedFileAction
  // ---------------------------------------------------------------------------
  group('RemoveSelectedFileAction', () {
    test('removes the file at the given index', () {
      final a = _makeTextFile('a.txt', 'A');
      final b = _makeTextFile('b.txt', 'B');
      final c = _makeTextFile('c.txt', 'C');

      final notifier = ReduxNotifier.test(
        redux: SelectedSendingFilesNotifier(),
        initialState: [a, b, c],
      );

      notifier.dispatch(RemoveSelectedFileAction(1));

      expect(notifier.state.length, 2);
      expect(utf8.decode(notifier.state[0].bytes!), 'A');
      expect(utf8.decode(notifier.state[1].bytes!), 'C');
    });
  });

  // ---------------------------------------------------------------------------
  // ClearSelectionAction
  // ---------------------------------------------------------------------------
  group('ClearSelectionAction', () {
    test('empties the list', () {
      final notifier = ReduxNotifier.test(
        redux: SelectedSendingFilesNotifier(),
        initialState: [_makeTextFile('x.txt', 'X')],
      );

      notifier.dispatch(ClearSelectionAction());

      expect(notifier.state, isEmpty);
    });
  });
}

CrossFile _makeTextFile(String name, String message) {
  final bytes = utf8.encode(message);
  return CrossFile(
    name: name,
    fileType: FileType.text,
    size: bytes.length,
    thumbnail: null,
    asset: null,
    path: null,
    bytes: bytes,
    lastModified: null,
    lastAccessed: null,
  );
}
