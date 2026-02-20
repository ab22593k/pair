import 'package:terminal/main.dart';
import 'package:test/test.dart';

void main() {
  group('LocalSendCli', () {
    late PairTRM cli;

    setUp(() {
      cli = PairTRM();
    });

    test('prints usage when --help flag is passed', () async {
      int? exitCode;
      await expectLater(
        () async => exitCode = await cli.run(['--help']),
        prints(allOf(
          contains('The LocalSend CLI to send and receive files locally.'),
          contains('-h, --help'),
          contains('-r, --receive'),
          contains('-s, --send'),
        )),
      );
      expect(exitCode, 0);
    });

    test('prints usage when -h flag is passed', () async {
      int? exitCode;
      await expectLater(
        () async => exitCode = await cli.run(['-h']),
        prints(allOf(
          contains('The LocalSend CLI to send and receive files locally.'),
          contains('-h, --help'),
        )),
      );
      expect(exitCode, 0);
    });

    test('prints server message when --receive flag is passed', () async {
      int? exitCode;
      await expectLater(
        () async => exitCode = await cli.run(['--receive']),
        prints('Starting server...\n'),
      );
      expect(exitCode, 0);
    });

    test('prints client message when --send flag is passed', () async {
      int? exitCode;
      await expectLater(
        () async => exitCode = await cli.run(['--send']),
        prints('Setting up client...\n'),
      );
      expect(exitCode, 0);
    });

    test('prints usage when no flags are passed', () async {
      int? exitCode;
      await expectLater(
        () async => exitCode = await cli.run([]),
        prints(allOf(
          contains('The LocalSend CLI to send and receive files locally.'),
          contains('-h, --help'),
        )),
      );
      expect(exitCode, 0);
    });

    test('prints error and usage on invalid argument', () async {
      int? exitCode;
      await expectLater(
        () async => exitCode = await cli.run(['--invalid']),
        prints(allOf(
          contains('Could not find an option named "invalid".'),
          contains('Usage:'),
        )),
      );
      expect(exitCode, 1);
    });
  });
}
