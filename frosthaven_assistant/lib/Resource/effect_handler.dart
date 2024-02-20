import 'package:frosthaven_assistant/Resource/line_builder/stat_applier.dart';
import 'package:frosthaven_assistant/Resource/state/game_state.dart';

import '../services/service_locator.dart';
import 'commands/change_stat_commands/change_health_command.dart';
import 'commands/remove_condition_command.dart';
import 'enums.dart';

class FigureData {
  final String ownerId;
  final String figureId;
  late final FigureState state;

  ListItemData? getOwner () {
    for (var item in getIt<GameState>().currentList) {
       if (item.id == ownerId) {
         return item;
       }
    }

    return null;
  }

  FigureData(this.ownerId, this.figureId) {
    state = GameMethods.getFigure(ownerId, figureId)!;
  }
}

class EffectHandler {
  static final List<Condition> _poisonConditions = [
    Condition.poison4,
    Condition.poison3,
    Condition.poison2,
    Condition.poison,
  ];

  static  final List<Condition> _woundConditions = [
    Condition.wound2,
    Condition.wound,
  ];

  static void handleMonsterRoundStart(Monster monster) {
    if (monster.monsterInstances.isEmpty) {
      return;
    }

    var gameState = getIt<GameState>();
    var round = gameState.round.value;

    for (var instance in monster.monsterInstances) {
      if (instance.startedRound.value == round) {
        continue;
      }

      var figure = FigureData(monster.id, instance.getId());
      _applyRoundStartEffects(figure);
      instance.startedRound.value = round;
    }
  }

  static void handleMonsterRoundEnd(Monster monster) {
    if (monster.monsterInstances.isEmpty) {
      return;
    }

    var gameState = getIt<GameState>();
    var round = gameState.round.value;

    for (var instance in monster.monsterInstances) {
      if (instance.endedRound.value == round) {
        continue;
      }

      var figure = FigureData(monster.id, instance.getId());
      _applyRoundEndEffects(figure);
      instance.endedRound.value = round;
    }
  }

  static void handleCharacterRoundStart(Character character) {
    if (character.characterState.health.value <= 0) {
      return;
    }

    var gameState = getIt<GameState>();
    var round = gameState.round.value;

    if (character.characterState.startedRound.value == round) {
      return;
    }

    var figure = FigureData(character.id, character.id);
    _applyRoundStartEffects(figure);
    character.characterState.startedRound.value = round;
  }

  static void handleCharacterRoundEnd(Character character) {
    if (character.characterState.health.value <= 0) {
      return;
    }

    var gameState = getIt<GameState>();
    var round = gameState.round.value;

    if (character.characterState.endedRound.value == round) {
      return;
    }
    var figure = FigureData(character.id, character.id);
    _applyRoundEndEffects(figure);
    character.characterState.endedRound.value = round;
  }

  static void _applyRoundStartEffects(FigureData figure) {
    if (_isConditionActive(Condition.regenerate, figure)) {
      handleHealthChange(figure, 1, false);
    }

    var woundValue = _getWoundAmount(figure);
    if (woundValue != 0) {
      handleHealthChange(figure, woundValue, false);
    }
  }

  static void _applyRoundEndEffects(FigureData figure) { }

  static void handleHealthChange(FigureData figure, int initialChange, bool attack) {
    if (initialChange == 0) {
      return;
    }

    var amount = initialChange < 0 ?
      _calculateDamage(initialChange, figure, attack) :
      _calculateHeal(initialChange, figure);

    amount = _normalizeHealthChangeAmount(amount, figure);

    if (amount == 0) {
      return;
    }

    var command = ChangeHealthCommand(amount, figure.figureId, figure.ownerId);
    var gameState = getIt<GameState>();

    gameState.action(command);
  }

  static int _calculateDamage(int initialAmount, FigureData figure, bool attack) {
    var amount = initialAmount;

    if (_isConditionActive(Condition.ward, figure) && _isConditionActive(Condition.brittle, figure)) {
      _removeCondition(Condition.ward, figure);
      _removeCondition(Condition.brittle, figure);
    }

    if (_isConditionActive(Condition.ward, figure)) {
      amount = (amount / 2).floor();

      _removeCondition(Condition.ward, figure);
    }

    if (_isConditionActive(Condition.brittle, figure)) {
      amount *= 2;

      _removeCondition(Condition.brittle, figure);
    }

    if (attack) {
      amount += _getPoisonAmount(figure);
      amount += _getShieldAmount(figure);
    }

    if (amount < 0) {
      _removeCondition(Condition.regenerate, figure);
    }

    if (amount > 0) {
      return 0;
    }

    return amount;
  }

  static int _calculateHeal(int initialAmount, FigureData figure) {
    var amount = initialAmount;

    var isWounded = _getWoundAmount(figure) != 0;
    if (isWounded) {
      _removeWound(figure);
    }

    var isPoisoned = _getPoisonAmount(figure) != 0;
    if (isPoisoned) {
      _removePoison(figure);

      amount = 0;
    }

    if (amount < 0) {
      return 0;
    }

    return amount;
  }

  static int _normalizeHealthChangeAmount (int amount, FigureData figure) {
    var health = figure.state.health.value;
    var maxHealth = figure.state.maxHealth.value;

    if (health + amount < 0) {
      return health * -1;
    }
    if (health + amount > maxHealth) {
      return maxHealth - health;
    }

    return amount;
  }

  static bool _isConditionActive(Condition condition, FigureData figure) {
    bool isActive = false;
    for (var item in figure.state.conditions.value) {
      if (item == condition) {
        isActive = true;
        break;
      }
    }
    return isActive;
  }

  static void _removeCondition(Condition condition, FigureData figure) {
    if (!_isConditionActive(condition, figure)) {
      return;
    }

    var gameState = getIt<GameState>();
    var command = RemoveConditionCommand(condition, figure.figureId, figure.ownerId);

    gameState.action(command);
  }

  static void _removePoison(FigureData figure) {
    for (var condition in _poisonConditions) {
      _removeCondition(condition, figure);
    }
  }

  static void _removeWound(FigureData figure) {
    for (var condition in _woundConditions) {
      _removeCondition(condition, figure);
    }
  }

  static int _getPoisonAmount(FigureData figure) {
    if (_isConditionActive(Condition.poison4, figure)) {
      return -4;
    }
    if (_isConditionActive(Condition.poison3, figure)) {
      return -3;
    }
    if (_isConditionActive(Condition.poison2, figure)) {
      return -2;
    }
    if (_isConditionActive(Condition.poison, figure)) {
      return -1;
    }
    return 0;
  }

  static int _getWoundAmount(FigureData figure) {
    if (_isConditionActive(Condition.wound2, figure)) {
      return -2;
    }
    if (_isConditionActive(Condition.wound, figure)) {
      return -1;
    }
    return 0;
  }

  static int _getShieldAmount(FigureData figure) {
    var owner = figure.getOwner();

    if (owner is Monster) {
      var elite = (figure.state as MonsterInstance).type == MonsterType.elite;
      var stats = StatApplier.getStatTokens(owner, elite);

      return stats['shield'] ?? 0;
    }

    return 0;
  }
}
