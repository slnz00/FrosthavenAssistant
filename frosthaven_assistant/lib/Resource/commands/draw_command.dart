import 'package:frosthaven_assistant/Resource/effect_handler.dart';

import '../../Layout/main_list.dart';
import '../../services/service_locator.dart';
import '../enums.dart';
import '../state/game_state.dart';

class DrawCommand extends Command {
  final GameState _gameState = getIt<GameState>();

  DrawCommand();

  @override
  void execute() {
    GameMethods.drawAbilityCards(stateAccess);
    GameMethods.sortByInitiative(stateAccess);
    GameMethods.setRoundState(stateAccess, RoundState.playTurns);
    if (_gameState.currentList.isNotEmpty) {
      var data = _gameState.currentList[0];

      data.setTurnState(TurnsState.current);

      if (data is Monster) {
        EffectHandler.handleMonsterRoundStart(data);
      }
      if (data is Character) {
        EffectHandler.handleCharacterRoundStart(data);
      }
    }

    Future.delayed(const Duration(milliseconds: 600), () {
      _gameState.updateList.value++;
      MainList.scrollToTop();
    });
  }

  @override
  void undo() {
    _gameState.updateList.value++;
  }

  @override
  String describe() {
    return "Draw";
  }
}
