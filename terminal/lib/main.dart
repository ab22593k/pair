import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as path;

class PairTRM {
  Future<int> run(List<String> arguments) async {
    final parser = _buildParser();

    try {
      final results = parser.parse(arguments);

      if (results['help'] as bool) {
        _printUsage(parser);
        return 0;
      }

      final receive = results['receive'] as bool;
      final send = results['send'] as bool;

      if (receive) {
        _startServer();
      } else if (send) {
        _setupClient();
      } else {
        _printUsage(parser);
      }
      return 0;
    } on FormatException catch (e) {
      print(e.message);
      print('');
      _printUsage(parser);
      return 1;
    }
  }

  ArgParser _buildParser() {
    final parser = ArgParser();

    parser.addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Prints usage information',
      defaultsTo: false,
    );
    parser.addFlag(
      'receive',
      abbr: 'r',
      negatable: false,
      help: 'Start a server to receive files',
      defaultsTo: false,
    );
    parser.addFlag(
      'send',
      abbr: 's',
      negatable: false,
      help: 'Setups a client to send files',
      defaultsTo: false,
    );

    return parser;
  }

  void _startServer() {
    print('Starting server...');
  }

  void _setupClient() {
    print('Setting up client...');
  }

  void _printUsage(ArgParser parser) {
    print('The LocalSend CLI to send and receive files locally.');
    print('');
    print('Usage: ${path.basename(Platform.executable)} [options]');
    print('');
    print('Options:');
    print(parser.usage);
  }
}

Future<void> main(List<String> arguments) async {
  final exitCode = await PairTRM().run(arguments);
  exit(exitCode);
}
