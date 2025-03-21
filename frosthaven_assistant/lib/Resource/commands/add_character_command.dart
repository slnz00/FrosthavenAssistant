import '../../services/service_locator.dart';
import '../state/game_state.dart';

class AddCharacterCommand extends Command {
  final GameState _gameState = getIt<GameState>();
  final String _name;
  final int _level;
  final String? _display;
  late Character character;

  AddCharacterCommand(this._name, this._display, this._level) {
    character = GameMethods.createCharacter(stateAccess, _name, _display, _level)!;
  }

  @override
  void execute() {
    //add new character on top of list
    GameMethods.addToMainList(stateAccess, 0, character);

    GameMethods.updateForSpecialRules(stateAccess);
    _gameState.updateList.value++;
    GameMethods.unlockClass(stateAccess, character.characterClass.name);
  }

  @override
  void undo() {
    _gameState.updateList.value++;
  }

  @override
  String describe() {
    return "Add $_name";
  }
}
