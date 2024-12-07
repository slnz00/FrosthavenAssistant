import '../../../services/service_locator.dart';
import '../../state/game_state.dart';
import 'change_stat_command.dart';

class ChangeMaxHealthCommand extends ChangeStatCommand {
  ChangeMaxHealthCommand(super.change, super.figureId, super.ownerId);

  @override
  void execute() {
    FigureState figure = GameMethods.getFigure(ownerId, figureId)!;

    int newValue = figure.maxHealth.value + change;
    if(newValue <= 0) {
      return;
    }

    figure.setMaxHealth(stateAccess, newValue);

    //lower health if max health lowers
    if (figure.maxHealth.value < figure.health.value) {
      figure.setHealth(stateAccess, figure.maxHealth.value);
    }
    //if health same as max health, then let health follow?
    if (figure.maxHealth.value - change == figure.health.value) {
      figure.setHealth(stateAccess, figure.maxHealth.value);
    }

    if (figure.maxHealth.value <= 0) {
      handleDeath();
    }
  }

  @override
  void undo() {
    //stat.value -= change;
    getIt<GameState>().updateList.value++;
  }

  @override
  String describe() {
    if (change > 0) {
      return "Increase $ownerId's max health";
    }
    return "Decrease $ownerId's max health";
  }
}
