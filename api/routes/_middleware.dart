import 'dart:io';

import 'package:cards_repository/cards_repository.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:game_script_machine/game_script_machine.dart';
import 'package:logging/logging.dart';
import 'package:match_repository/match_repository.dart';
import 'package:scripts_repository/scripts_repository.dart';
import 'package:shelf_cors_headers/shelf_cors_headers.dart';

import '../main.dart';

Handler middleware(Handler handler) {
  return handler
      .use(requestLogger())
      .use(provider<Logger>((_) => Logger.root))
      .use(provider<CardsRepository>((_) => cardsRepository))
      .use(provider<MatchRepository>((_) => matchRepository))
      .use(provider<ScriptsRepository>((_) => scriptsRepository))
      .use(provider<GameScriptMachine>((_) => gameScriptMachine))
      .use(jwtMiddleware.middleware)
      .use(encryptionMiddleware.middleware)
      .use(
        fromShelfMiddleware(
          corsHeaders(
            headers: {
              ACCESS_CONTROL_ALLOW_ORIGIN: _corsDomain,
            },
          ),
        ),
      );
}

String get _corsDomain {
  final value = Platform.environment['CORS_DOMAIN'];
  if (value == null) {
    throw ArgumentError('CORS_DOMAIN is required to run the API');
  }
  return value;
}
