import 'package:frosthaven_assistant/Resource/state/game_state.dart';

import '../../services/service_locator.dart';
import '../action_handler.dart';
import '../enums.dart';

class SummonData {
  int standeeNr;
  String name;
  int health;
  int move;
  int attack;
  int range;
  int shield;
  String gfx;

  SummonData(this.standeeNr, this.name, this.health, this.move, this.attack,
      this.range, this.shield, this.gfx);
}

class AddStandeeCommand extends Command {
  final int nr;

  final SummonData? summon;
  final MonsterType type;
  final String ownerId;
  final bool addAsSummon;
  final bool ally;

  AddStandeeCommand(
      this.nr, this.summon, this.ownerId, this.type, this.addAsSummon, [this.ally = false]);

  @override
  void execute() {
    GameMethods.executeAddStandee(stateAccess, nr, summon, type, ownerId, addAsSummon, ally);

    if (getIt<GameState>().roundState.value == RoundState.playTurns) {
      Future.delayed(const Duration(milliseconds: 600), () {
        getIt<GameState>().updateList.value++;
      });
    } else {
      getIt<GameState>().updateList.value++;
    }
    //getIt<GameState>().updateList.value++;
  }

  @override
  void undo() {
    getIt<GameState>().updateList.value++;
  }

  @override
  String describe() {
    String name = ownerId;
    if (summon != null) {
      name = summon!.name;
    }
    return "Add $name $nr";
  }
}
