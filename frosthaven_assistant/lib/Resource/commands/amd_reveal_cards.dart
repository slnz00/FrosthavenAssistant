import '../../services/service_locator.dart';
import '../state/game_state.dart';

class AMDRevealCards extends Command {
  final GameState _gameState = getIt<GameState>();
  final bool ally;
  final int revealed;
  AMDRevealCards(this.ally, this.revealed);

  @override
  void execute() {
    if (ally) {
      _gameState.modifierDeckAllies.setRevealed(revealed);
    } else {
      _gameState.modifierDeck.setRevealed(revealed);
    }
  }

  @override
  void undo() {}

  @override
  String describe() {
    return "Reveal attack modifiers";
  }
}