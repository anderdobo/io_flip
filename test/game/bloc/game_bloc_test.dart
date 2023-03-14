// ignore_for_file: prefer_const_constructors

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_client/game_client.dart';
import 'package:game_domain/game_domain.dart';
import 'package:match_maker_repository/match_maker_repository.dart' as repo;
import 'package:mocktail/mocktail.dart';
import 'package:top_dash/game/game.dart';

class _MockGameClient extends Mock implements GameClient {}

class _MockMatchMakerRepository extends Mock
    implements repo.MatchMakerRepository {}

class _MockMatchSolver extends Mock implements MatchSolver {}

void main() {
  group('GameBloc', () {
    final match = Match(
      id: 'matchId',
      hostDeck: Deck(id: '', cards: const []),
      guestDeck: Deck(id: '', cards: const []),
    );
    final matchState = MatchState(
      id: 'matchStateId',
      matchId: match.id,
      guestPlayedCards: const [],
      hostPlayedCards: const [],
    );

    late StreamController<MatchState> matchStateController;
    late StreamController<repo.Match> matchController;
    late GameClient gameClient;
    late repo.MatchMakerRepository matchMakerRepository;
    late MatchSolver matchSolver;
    const isHost = true;

    setUpAll(() {
      registerFallbackValue(match);
      registerFallbackValue(matchState);
    });

    setUp(() {
      matchSolver = _MockMatchSolver();
      gameClient = _MockGameClient();
      matchMakerRepository = _MockMatchMakerRepository();

      when(() => gameClient.getMatch(match.id)).thenAnswer((_) async => match);
      when(() => gameClient.getMatchState(match.id))
          .thenAnswer((_) async => matchState);

      matchStateController = StreamController();
      matchController = StreamController();

      when(() => matchMakerRepository.watchMatchState(any()))
          .thenAnswer((_) => matchStateController.stream);

      when(() => matchMakerRepository.watchMatch(any()))
          .thenAnswer((_) => matchController.stream);

      when(() => matchMakerRepository.pingHost(any())).thenAnswer((_) async {});

      when(() => matchMakerRepository.pingGuest(any()))
          .thenAnswer((_) async {});
    });

    test('can be instantiated', () {
      expect(
        GameBloc(
          gameClient: _MockGameClient(),
          matchMakerRepository: _MockMatchMakerRepository(),
          matchSolver: matchSolver,
          isHost: true,
        ),
        isNotNull,
      );
    });

    test('has the correct initial state', () {
      expect(
        GameBloc(
          gameClient: _MockGameClient(),
          matchMakerRepository: _MockMatchMakerRepository(),
          matchSolver: matchSolver,
          isHost: false,
        ).state,
        equals(MatchLoadingState()),
      );
    });

    blocTest<GameBloc, GameState>(
      'loads a match',
      build: () => GameBloc(
        gameClient: gameClient,
        matchMakerRepository: matchMakerRepository,
        matchSolver: matchSolver,
        isHost: isHost,
      ),
      act: (bloc) => bloc.add(MatchRequested(match.id)),
      expect: () => [
        MatchLoadingState(),
        MatchLoadedState(
          match: match,
          matchState: matchState,
          turns: const [],
          playerPlayed: false,
        ),
      ],
      verify: (_) {
        verify(() => gameClient.getMatch(match.id)).called(1);
      },
    );

    blocTest<GameBloc, GameState>(
      'fails when the match is not found',
      build: () => GameBloc(
        gameClient: gameClient,
        matchMakerRepository: matchMakerRepository,
        matchSolver: matchSolver,
        isHost: isHost,
      ),
      setUp: () {
        when(() => gameClient.getMatch(match.id)).thenAnswer((_) async => null);
      },
      act: (bloc) => bloc.add(MatchRequested(match.id)),
      expect: () => [
        MatchLoadingState(),
        MatchLoadFailedState(),
      ],
    );

    blocTest<GameBloc, GameState>(
      'fails when fetching the match throws an exception',
      build: () => GameBloc(
        gameClient: gameClient,
        matchMakerRepository: matchMakerRepository,
        matchSolver: matchSolver,
        isHost: isHost,
      ),
      setUp: () {
        when(() => gameClient.getMatch(match.id)).thenThrow(Exception('Ops'));
      },
      act: (bloc) => bloc.add(MatchRequested(match.id)),
      expect: () => [
        MatchLoadingState(),
        MatchLoadFailedState(),
      ],
    );

    group('register player and opponent moves', () {
      const baseState = MatchLoadedState(
        match: Match(
          id: 'matchId',
          hostDeck: Deck(
            id: 'hostDeck',
            cards: [
              Card(
                id: 'card1',
                name: '',
                description: '',
                image: '',
                power: 10,
                rarity: false,
              ),
              Card(
                id: 'card2',
                name: '',
                description: '',
                image: '',
                power: 10,
                rarity: false,
              ),
              Card(
                id: 'card3',
                name: '',
                description: '',
                image: '',
                power: 10,
                rarity: false,
              ),
            ],
          ),
          guestDeck: Deck(
            id: 'guestDeck',
            cards: [
              Card(
                id: 'card4',
                name: '',
                description: '',
                image: '',
                power: 10,
                rarity: false,
              ),
              Card(
                id: 'card5',
                name: '',
                description: '',
                image: '',
                power: 10,
                rarity: false,
              ),
              Card(
                id: 'card6',
                name: '',
                description: '',
                image: '',
                power: 10,
                rarity: false,
              ),
            ],
          ),
        ),
        matchState: MatchState(
          id: 'matchStateId',
          matchId: 'matchId',
          hostPlayedCards: [],
          guestPlayedCards: [],
        ),
        turns: [],
        playerPlayed: false,
      );

      setUp(() {
        when(
          () => gameClient.playCard(
            matchId: 'matchId',
            cardId: any(named: 'cardId'),
            isHost: any(named: 'isHost'),
          ),
        ).thenAnswer((_) async {});
      });

      test('adds a new state change when the entity changes', () async {
        final bloc = GameBloc(
          gameClient: gameClient,
          matchMakerRepository: matchMakerRepository,
          matchSolver: matchSolver,
          isHost: true,
        )..add(MatchRequested(baseState.match.id));

        await Future.microtask(() {});

        matchStateController.add(
          MatchState(
            id: baseState.matchState.id,
            matchId: baseState.matchState.matchId,
            hostPlayedCards: baseState.matchState.hostPlayedCards,
            guestPlayedCards: const ['card6'],
          ),
        );

        await Future<void>.delayed(Duration(milliseconds: 20));

        final state = bloc.state;
        expect(state, isA<MatchLoadedState>());

        final matchLoadedState = state as MatchLoadedState;
        expect(
          matchLoadedState.turns,
          equals(
            [
              MatchTurn(
                playerCardId: null,
                opponentCardId: 'card6',
              ),
            ],
          ),
        );
      });

      blocTest<GameBloc, GameState>(
        'canPlayerPlay calls match solver correctly',
        build: () => GameBloc(
          gameClient: gameClient,
          matchMakerRepository: matchMakerRepository,
          matchSolver: matchSolver,
          isHost: true,
        ),
        setUp: () {
          when(
            () => matchSolver.canPlayCard(baseState.matchState, isHost: true),
          ).thenReturn(true);
        },
        seed: () => baseState,
        act: (bloc) => bloc.canPlayerPlay(),
        verify: (_) {
          verify(
            () => matchSolver.canPlayCard(baseState.matchState, isHost: true),
          ).called(1);
        },
      );

      blocTest<GameBloc, GameState>(
        'isWinningCard return correctly when is host',
        build: () => GameBloc(
          gameClient: gameClient,
          matchMakerRepository: matchMakerRepository,
          matchSolver: matchSolver,
          isHost: true,
        ),
        setUp: () {
          when(() => matchSolver.calculateRoundResult(any(), any(), any()))
              .thenReturn(MatchResult.host);
        },
        seed: () => baseState.copyWith(
          matchState: MatchState(
            id: 'matchStateId',
            matchId: 'matchId',
            hostPlayedCards: const ['card1'],
            guestPlayedCards: const ['card6'],
          ),
          turns: [
            MatchTurn(
              playerCardId: 'card1',
              opponentCardId: 'card6',
            ),
          ],
        ),
        verify: (bloc) {
          expect(
            bloc.isWiningCard(
              baseState.match.hostDeck.cards
                  .firstWhere((card) => card.id == 'card1'),
              isPlayer: true,
            ),
            isTrue,
          );
        },
      );

      blocTest<GameBloc, GameState>(
        'hasPlayerWon returns true if the host won, and the player is the host',
        build: () => GameBloc(
          gameClient: gameClient,
          matchMakerRepository: matchMakerRepository,
          matchSolver: matchSolver,
          isHost: true,
        ),
        seed: () => baseState.copyWith(
          matchState: MatchState(
            id: baseState.matchState.id,
            matchId: baseState.matchState.id,
            guestPlayedCards: baseState.matchState.guestPlayedCards,
            hostPlayedCards: baseState.matchState.hostPlayedCards,
            result: MatchResult.host,
          ),
        ),
        verify: (bloc) {
          expect(bloc.hasPlayerWon(), isTrue);
        },
      );

      blocTest<GameBloc, GameState>(
        'hasPlayerWon returns false if the guest won, and the player '
        'is the guest',
        build: () => GameBloc(
          gameClient: gameClient,
          matchMakerRepository: matchMakerRepository,
          matchSolver: matchSolver,
          isHost: false,
        ),
        seed: () => baseState.copyWith(
          matchState: MatchState(
            id: baseState.matchState.id,
            matchId: baseState.matchState.id,
            guestPlayedCards: baseState.matchState.guestPlayedCards,
            hostPlayedCards: baseState.matchState.hostPlayedCards,
            result: MatchResult.guest,
          ),
        ),
        verify: (bloc) {
          expect(bloc.hasPlayerWon(), isTrue);
        },
      );

      blocTest<GameBloc, GameState>(
        'hasPlayerWon returns false if match is still loading',
        build: () => GameBloc(
          gameClient: gameClient,
          matchMakerRepository: matchMakerRepository,
          matchSolver: matchSolver,
          isHost: false,
        ),
        seed: () => const MatchLoadingState(),
        verify: (bloc) {
          expect(bloc.hasPlayerWon(), isFalse);
        },
      );

      blocTest<GameBloc, GameState>(
        'isWinningCard return correctly when is guest',
        build: () => GameBloc(
          gameClient: gameClient,
          matchMakerRepository: matchMakerRepository,
          matchSolver: matchSolver,
          isHost: false,
        ),
        setUp: () {
          when(() => matchSolver.calculateRoundResult(any(), any(), any()))
              .thenReturn(MatchResult.guest);
        },
        seed: () => baseState.copyWith(
          matchState: MatchState(
            id: 'matchStateId',
            matchId: 'matchId',
            hostPlayedCards: const ['card1'],
            guestPlayedCards: const ['card6'],
          ),
          turns: [
            MatchTurn(
              playerCardId: 'card6',
              opponentCardId: 'card1',
            ),
          ],
        ),
        verify: (bloc) {
          expect(
            bloc.isWiningCard(
              baseState.match.guestDeck.cards
                  .firstWhere((card) => card.id == 'card6'),
              isPlayer: true,
            ),
            isTrue,
          );
        },
      );

      blocTest<GameBloc, GameState>(
        'plays a player card',
        build: () => GameBloc(
          gameClient: gameClient,
          matchMakerRepository: matchMakerRepository,
          matchSolver: matchSolver,
          isHost: true,
        ),
        seed: () => baseState,
        act: (bloc) => bloc.add(PlayerPlayed('new_card_1')),
        expect: () => [
          MatchLoadedState(
            match: baseState.match,
            matchState: MatchState(
              id: 'matchStateId',
              matchId: baseState.match.id,
              guestPlayedCards: const [],
              hostPlayedCards: const [],
            ),
            turns: const [],
            playerPlayed: true,
          ),
        ],
      );

      blocTest<GameBloc, GameState>(
        'plays a player card when being the guest',
        build: () => GameBloc(
          gameClient: gameClient,
          matchMakerRepository: matchMakerRepository,
          matchSolver: matchSolver,
          isHost: false,
        ),
        seed: () => baseState,
        act: (bloc) => bloc.add(PlayerPlayed('new_card_1')),
        expect: () => [
          MatchLoadedState(
            match: baseState.match,
            matchState: MatchState(
              id: 'matchStateId',
              matchId: baseState.match.id,
              guestPlayedCards: const [],
              hostPlayedCards: const [],
            ),
            turns: const [],
            playerPlayed: true,
          ),
        ],
      );

      blocTest<GameBloc, GameState>(
        'marks the playerPlayer as false on receive the new state',
        build: () => GameBloc(
          gameClient: gameClient,
          matchMakerRepository: matchMakerRepository,
          matchSolver: matchSolver,
          isHost: true,
        ),
        seed: () => baseState,
        act: (bloc) {
          bloc
            ..add(PlayerPlayed('new_card_1'))
            ..add(
              MatchStateUpdated(
                MatchState(
                  id: baseState.matchState.id,
                  matchId: baseState.matchState.matchId,
                  hostPlayedCards: const ['new_card_1'],
                  guestPlayedCards: baseState.matchState.guestPlayedCards,
                ),
              ),
            );
        },
        expect: () => [
          MatchLoadedState(
            match: baseState.match,
            matchState: MatchState(
              id: 'matchStateId',
              matchId: baseState.match.id,
              guestPlayedCards: const [],
              hostPlayedCards: const [],
            ),
            turns: const [],
            playerPlayed: true,
          ),
          MatchLoadedState(
            match: baseState.match,
            matchState: MatchState(
              id: 'matchStateId',
              matchId: baseState.match.id,
              guestPlayedCards: const [],
              hostPlayedCards: const ['new_card_1'],
            ),
            turns: const [
              MatchTurn(
                opponentCardId: null,
                playerCardId: 'new_card_1',
              ),
            ],
            playerPlayed: false,
          ),
        ],
      );

      blocTest<GameBloc, GameState>(
        'marks the playerPlayer as false on receive the new state when being '
        'the guest',
        build: () => GameBloc(
          gameClient: gameClient,
          matchMakerRepository: matchMakerRepository,
          matchSolver: matchSolver,
          isHost: false,
        ),
        seed: () => baseState,
        act: (bloc) {
          bloc
            ..add(PlayerPlayed('new_card_1'))
            ..add(
              MatchStateUpdated(
                MatchState(
                  id: baseState.matchState.id,
                  matchId: baseState.matchState.matchId,
                  hostPlayedCards: baseState.matchState.hostPlayedCards,
                  guestPlayedCards: const ['new_card_1'],
                ),
              ),
            );
        },
        expect: () => [
          MatchLoadedState(
            match: baseState.match,
            matchState: MatchState(
              id: 'matchStateId',
              matchId: baseState.match.id,
              guestPlayedCards: const [],
              hostPlayedCards: const [],
            ),
            turns: const [],
            playerPlayed: true,
          ),
          MatchLoadedState(
            match: baseState.match,
            matchState: MatchState(
              id: 'matchStateId',
              matchId: baseState.match.id,
              guestPlayedCards: const ['new_card_1'],
              hostPlayedCards: const [],
            ),
            turns: const [
              MatchTurn(
                opponentCardId: null,
                playerCardId: 'new_card_1',
              ),
            ],
            playerPlayed: false,
          ),
        ],
      );

      blocTest<GameBloc, GameState>(
        'plays a player card, receives confirmation and then receives an '
        'opponent card',
        build: () => GameBloc(
          gameClient: gameClient,
          matchMakerRepository: matchMakerRepository,
          matchSolver: matchSolver,
          isHost: true,
        ),
        seed: () => baseState,
        act: (bloc) {
          bloc
            ..add(PlayerPlayed('new_card_1'))
            ..add(
              MatchStateUpdated(
                MatchState(
                  id: baseState.matchState.id,
                  matchId: baseState.matchState.matchId,
                  hostPlayedCards: const ['new_card_1'],
                  guestPlayedCards: baseState.matchState.guestPlayedCards,
                ),
              ),
            )
            ..add(
              MatchStateUpdated(
                MatchState(
                  id: baseState.matchState.id,
                  matchId: baseState.matchState.matchId,
                  hostPlayedCards: const ['new_card_1'],
                  guestPlayedCards: const ['new_card_2'],
                ),
              ),
            );
        },
        expect: () => [
          MatchLoadedState(
            match: baseState.match,
            matchState: MatchState(
              id: 'matchStateId',
              matchId: baseState.match.id,
              guestPlayedCards: const [],
              hostPlayedCards: const [],
            ),
            turns: const [],
            playerPlayed: true,
          ),
          MatchLoadedState(
            match: baseState.match,
            matchState: MatchState(
              id: 'matchStateId',
              matchId: baseState.match.id,
              guestPlayedCards: const [],
              hostPlayedCards: const ['new_card_1'],
            ),
            turns: const [
              MatchTurn(
                opponentCardId: null,
                playerCardId: 'new_card_1',
              ),
            ],
            playerPlayed: false,
          ),
          MatchLoadedState(
            match: baseState.match,
            matchState: MatchState(
              id: 'matchStateId',
              matchId: baseState.match.id,
              guestPlayedCards: const ['new_card_2'],
              hostPlayedCards: const ['new_card_1'],
            ),
            turns: const [
              MatchTurn(
                opponentCardId: 'new_card_2',
                playerCardId: 'new_card_1',
              ),
            ],
            playerPlayed: false,
          ),
        ],
      );

      blocTest<GameBloc, GameState>(
        'plays a player card and opponent card and another opponent one',
        build: () => GameBloc(
          gameClient: gameClient,
          matchMakerRepository: matchMakerRepository,
          matchSolver: matchSolver,
          isHost: true,
        ),
        seed: () => baseState,
        act: (bloc) {
          bloc
            ..add(PlayerPlayed('new_card_1'))
            ..add(
              MatchStateUpdated(
                MatchState(
                  id: baseState.matchState.id,
                  matchId: baseState.matchState.matchId,
                  hostPlayedCards: const ['new_card_1'],
                  guestPlayedCards: baseState.matchState.guestPlayedCards,
                ),
              ),
            )
            ..add(
              MatchStateUpdated(
                MatchState(
                  id: baseState.matchState.id,
                  matchId: baseState.matchState.matchId,
                  hostPlayedCards: const ['new_card_1'],
                  guestPlayedCards: const ['new_card_2'],
                ),
              ),
            )
            ..add(
              MatchStateUpdated(
                MatchState(
                  id: baseState.matchState.id,
                  matchId: baseState.matchState.matchId,
                  hostPlayedCards: const ['new_card_1'],
                  guestPlayedCards: const ['new_card_2', 'new_card_3'],
                ),
              ),
            );
        },
        expect: () => [
          MatchLoadedState(
            match: baseState.match,
            matchState: MatchState(
              id: 'matchStateId',
              matchId: baseState.match.id,
              guestPlayedCards: const [],
              hostPlayedCards: const [],
            ),
            turns: const [],
            playerPlayed: true,
          ),
          MatchLoadedState(
            match: baseState.match,
            matchState: MatchState(
              id: 'matchStateId',
              matchId: baseState.match.id,
              guestPlayedCards: const [],
              hostPlayedCards: const ['new_card_1'],
            ),
            turns: const [
              MatchTurn(
                opponentCardId: null,
                playerCardId: 'new_card_1',
              ),
            ],
            playerPlayed: false,
          ),
          MatchLoadedState(
            match: baseState.match,
            matchState: MatchState(
              id: 'matchStateId',
              matchId: baseState.match.id,
              guestPlayedCards: const ['new_card_2'],
              hostPlayedCards: const ['new_card_1'],
            ),
            turns: const [
              MatchTurn(
                opponentCardId: 'new_card_2',
                playerCardId: 'new_card_1',
              ),
            ],
            playerPlayed: false,
          ),
          MatchLoadedState(
            match: baseState.match,
            matchState: MatchState(
              id: 'matchStateId',
              matchId: baseState.match.id,
              guestPlayedCards: const ['new_card_2', 'new_card_3'],
              hostPlayedCards: const ['new_card_1'],
            ),
            turns: const [
              MatchTurn(
                opponentCardId: 'new_card_2',
                playerCardId: 'new_card_1',
              ),
              MatchTurn(
                opponentCardId: 'new_card_3',
                playerCardId: null,
              ),
            ],
            playerPlayed: false,
          ),
        ],
      );
    });

    group('MatchLoadedState', () {
      group('isCardTurnComplete', () {
        final match1 = Match(
          id: 'match1',
          hostDeck: Deck(id: '', cards: const []),
          guestDeck: Deck(id: '', cards: const []),
        );
        final matchState1 = MatchState(
          id: 'matchState1',
          matchId: match1.id,
          hostPlayedCards: const [],
          guestPlayedCards: const [],
        );
        final card = Card(
          id: '1',
          name: '',
          description: '',
          image: '',
          power: 10,
          rarity: false,
        );

        final baseState = MatchLoadedState(
          match: match1,
          matchState: matchState1,
          turns: const [],
          playerPlayed: false,
        );

        test('returns true if the card is the winning one', () {
          final state = baseState.copyWith(
            turns: [
              MatchTurn(
                opponentCardId: card.id,
                playerCardId: 'a',
              ),
            ],
          );

          expect(state.isCardTurnComplete(card), isTrue);
        });

        test('returns false if the turn is not complete', () {
          final state = baseState.copyWith(
            turns: [
              MatchTurn(
                opponentCardId: card.id,
                playerCardId: null,
              ),
            ],
          );

          expect(state.isCardTurnComplete(card), isFalse);
        });

        test('can detect the card turn no matter the order', () {
          final state = baseState.copyWith(
            turns: [
              MatchTurn(
                opponentCardId: 'a',
                playerCardId: card.id,
              ),
              MatchTurn(
                opponentCardId: 'b',
                playerCardId: null,
              ),
            ],
          );

          expect(state.isCardTurnComplete(card), isTrue);
        });
      });
    });

    group('MatchTurn', () {
      test('isComplete', () {
        expect(
          MatchTurn(playerCardId: null, opponentCardId: null).isComplete(),
          isFalse,
        );

        expect(
          MatchTurn(playerCardId: 'a', opponentCardId: null).isComplete(),
          isFalse,
        );

        expect(
          MatchTurn(playerCardId: null, opponentCardId: 'a').isComplete(),
          isFalse,
        );

        expect(
          MatchTurn(playerCardId: 'b', opponentCardId: 'a').isComplete(),
          isTrue,
        );
      });
    });

    group('manage player presence', () {
      final now = Timestamp.now();
      final staleDateTime = DateTime.now().subtract(Duration(seconds: 11));
      final opponentFailPing = Timestamp.fromDate(staleDateTime);
      final opponentPassPing = now;
      final playerPing = now;

      blocTest<GameBloc, GameState>(
        'pings the matching repository as host to show presence',
        build: () => GameBloc(
          gameClient: gameClient,
          matchMakerRepository: matchMakerRepository,
          isHost: true,
          timeOutPeriod: Duration(seconds: 10),
          pingInterval: Duration(microseconds: 1),
          matchSolver: matchSolver,
          now: () => now,
        ),
        act: (bloc) {
          bloc.add(ManagePlayerPresence(match.id));
        },
        expect: () => <GameState>[],
        verify: (_) {
          verify(() => matchMakerRepository.pingHost(match.id)).called(1);
        },
      );

      blocTest<GameBloc, GameState>(
        'pings the matching repository as guest to show presence',
        build: () => GameBloc(
          gameClient: gameClient,
          matchMakerRepository: matchMakerRepository,
          isHost: false,
          timeOutPeriod: Duration(seconds: 10),
          pingInterval: Duration(microseconds: 1),
          matchSolver: matchSolver,
          now: () => now,
        ),
        act: (bloc) {
          bloc.add(ManagePlayerPresence(match.id));
        },
        expect: () => <GameState>[],
        verify: (_) {
          verify(() => matchMakerRepository.pingGuest(match.id)).called(1);
        },
      );

      blocTest<GameBloc, GameState>(
        'notifies when opponent(guest) is absent',
        build: () => GameBloc(
          gameClient: gameClient,
          matchMakerRepository: matchMakerRepository,
          isHost: true,
          timeOutPeriod: Duration(seconds: 10),
          matchSolver: matchSolver,
          now: () => now,
        ),
        act: (bloc) {
          bloc.add(ManagePlayerPresence(match.id));
          matchController.add(
            repo.Match(
              id: 'matchId',
              host: 'hostId',
              guest: 'guestId',
              hostPing: playerPing,
              guestPing: opponentFailPing,
            ),
          );
        },
        expect: () => [OpponentAbsentState()],
        verify: (_) {
          verify(() => matchMakerRepository.watchMatch(match.id)).called(1);
        },
      );

      blocTest<GameBloc, GameState>(
        'notifies when opponent(host) is absent',
        build: () => GameBloc(
          gameClient: gameClient,
          matchMakerRepository: matchMakerRepository,
          isHost: false,
          matchSolver: matchSolver,
          now: () => now,
          timeOutPeriod: Duration(seconds: 10),
        ),
        act: (bloc) {
          bloc.add(ManagePlayerPresence(match.id));
          matchController.add(
            repo.Match(
              id: 'matchId',
              host: 'hostId',
              guest: 'guestId',
              hostPing: opponentFailPing,
              guestPing: playerPing,
            ),
          );
        },
        expect: () => [OpponentAbsentState()],
        verify: (_) {
          verify(() => matchMakerRepository.watchMatch(match.id)).called(1);
        },
      );

      blocTest<GameBloc, GameState>(
        'does not return a state if opponent is present',
        build: () => GameBloc(
          gameClient: gameClient,
          matchMakerRepository: matchMakerRepository,
          isHost: true,
          matchSolver: matchSolver,
          timeOutPeriod: Duration(seconds: 10),
          now: () => now,
        ),
        act: (bloc) {
          bloc.add(ManagePlayerPresence(match.id));
          matchController.add(
            repo.Match(
              id: 'matchId',
              host: 'hostId',
              guest: 'guestId',
              hostPing: playerPing,
              guestPing: opponentPassPing,
            ),
          );
        },
        expect: () => <GameState>[],
        verify: (_) {
          verify(() => matchMakerRepository.watchMatch(match.id)).called(1);
        },
      );

      blocTest<GameBloc, GameState>(
        'fails when fetching the match throws an exception',
        build: () => GameBloc(
          gameClient: gameClient,
          matchMakerRepository: matchMakerRepository,
          isHost: true,
          matchSolver: matchSolver,
          timeOutPeriod: Duration(seconds: 10),
          now: () => now,
        ),
        setUp: () {
          when(() => matchMakerRepository.watchMatch(any())).thenThrow(
            Exception('Ops'),
          );
        },
        act: (bloc) {
          bloc.add(ManagePlayerPresence(match.id));
          matchController.add(
            repo.Match(
              id: 'matchId',
              host: 'hostId',
              guest: 'guestId',
              hostPing: playerPing,
              guestPing: opponentPassPing,
            ),
          );
        },
        expect: () => [ManagePlayerPresenceFailedState()],
        verify: (_) {
          verify(() => matchMakerRepository.watchMatch(match.id)).called(1);
        },
      );

      blocTest<GameBloc, GameState>(
        'fails when pinging throws an exception',
        build: () => GameBloc(
          gameClient: gameClient,
          matchMakerRepository: matchMakerRepository,
          isHost: true,
          timeOutPeriod: Duration(seconds: 10),
          pingInterval: Duration(microseconds: 1),
          matchSolver: matchSolver,
          now: () => now,
        ),
        setUp: () {
          when(() => matchMakerRepository.pingHost(any())).thenThrow(
            Exception('Ops'),
          );
        },
        act: (bloc) {
          bloc.add(ManagePlayerPresence(match.id));
        },
        expect: () => [PingFailedState()],
        verify: (_) {
          verify(() => matchMakerRepository.pingHost(match.id)).called(1);
        },
      );
    });
  });
}