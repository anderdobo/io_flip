import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:game_client/game_client.dart';
import 'package:top_dash/draft/draft.dart';

class DraftPage extends StatelessWidget {
  const DraftPage({super.key});

  factory DraftPage.routeBuilder(_, __) {
    return const DraftPage(key: Key('draft'));
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final gameClient = context.read<GameClient>();
        return DraftBloc(
          gameClient: gameClient,
        )..add(const DeckRequested());
      },
      child: const DraftView(),
    );
  }
}
