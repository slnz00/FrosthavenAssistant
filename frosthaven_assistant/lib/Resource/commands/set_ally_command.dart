import 'package:frosthaven_assistant/Layout/menus/modifier_card_menu.dart';

import '../../Layout/menus/ability_cards_menu.dart';
import '../../services/service_locator.dart';
import '../state/game_state.dart';

class SetAllyCommand extends Command {
  final GameState _gameState = getIt<GameState>();
  final bool ally;
  final String ownerId;
  final String figureId;
  SetAllyCommand(this.ownerId, this.figureId, this.ally);

  @override
  void execute() {
    FigureState? figure = GameMethods.getFigure(ownerId, figureId);

    if (figure is! MonsterInstance) {
      return;
    }

    figure.ally = ally;

    getIt<GameState>().updateList.value++;
  }

  @override
  void undo() {}

  @override
  String describe() {
    return "Set monster ally status";
  }
}
