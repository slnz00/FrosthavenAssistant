import 'package:frosthaven_assistant/Layout/menus/modifier_card_menu.dart';

import '../../Layout/menus/ability_cards_menu.dart';
import '../../services/service_locator.dart';
import '../state/game_state.dart';

class ShuffleModifierDeckCommand extends Command {
  final GameState _gameState = getIt<GameState>();
  final bool ally;
  ShuffleModifierDeckCommand(this.ally);

  @override
  void execute() {
    if (ally) {
      _gameState.modifierDeckAllies.shuffle(stateAccess);
    } else {
      _gameState.modifierDeck.shuffle(stateAccess);
    }
  }

  @override
  void undo() {}

  @override
  String describe() {
    return "Shuffle attack modifier deck";
  }
}
