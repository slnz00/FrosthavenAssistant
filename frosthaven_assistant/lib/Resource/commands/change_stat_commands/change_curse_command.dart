import '../../../services/service_locator.dart';
import '../../state/game_state.dart';
import 'change_stat_command.dart';

class ChangeCurseCommand extends ChangeStatCommand {
  ChangeCurseCommand(super.change, super.figureId, super.ownerId);
  ChangeCurseCommand.deck(this.deck) : super(0, '', '');

  ModifierDeck? deck;

  @override
  void execute() {
    if (deck == null) {
      deck = getIt<GameState>().modifierDeck;
      //Figure figure = getFigure(ownerId, figureId)!;
      for (var item in getIt<GameState>().currentList) {
        if (item.id == ownerId) {
          if (item is Monster && item.isAlly) {
            deck = getIt<GameState>().modifierDeckAllies;
          }
        }
      }
    }

    if (deck!.curses.value < 0) {
      deck!.setCurse(stateAccess, 0);
      return;
    }

    if (deck!.curses.value + change < 0) {
      return;
    }

    deck!.setCurse(stateAccess, deck!.curses.value + change);
  }

  @override
  void undo() {
    //stat.value -= change;
    getIt<GameState>().updateList.value++;
  }

  @override
  String describe() {
    if (change > 0) {
      return "Add a Curse";
    }
    return "Remove a Curse";
  }
}
