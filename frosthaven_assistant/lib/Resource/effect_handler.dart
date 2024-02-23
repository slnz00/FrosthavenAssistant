import 'package:collection/collection.dart';
import 'package:frosthaven_assistant/Model/MonsterAbility.dart';
import 'package:frosthaven_assistant/Resource/line_builder/stat_applier.dart';
import 'package:frosthaven_assistant/Resource/state/game_state.dart';

import '../Layout/menus/action_menu.dart';
import '../services/service_locator.dart';
import 'commands/change_stat_commands/change_health_command.dart';
import 'commands/remove_condition_command.dart';
import 'commands/use_element_command.dart';
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

class MonsterAbilityAttribute {
  final String name;
  bool baseModifier = false;
  int baseValue = 0;
  int upgradeValue = 0;
  bool upgradeModifier = false;
  bool upgradeElementAny = false;
  Elements? upgradeElement = null;

  MonsterAbilityAttribute({required this.name});
}

class MonsterAbilityParser {
  static final Map<String, Elements> elementMap = {
    'air': Elements.air,
    'dark': Elements.dark,
    'earth': Elements.earth,
    'fire': Elements.fire,
    'ice': Elements.ice,
    'light': Elements.light,
  };

  static patternElementUse () {
    return r'%([^%]+)%%use%';
  }

  static patternBaseValue (String attributeName) {
    return r'%' + attributeName + '%[\\s]*([0-9]+)';
  }

  static patternModifierValue1 (String attributeName) {
    return r'%' + attributeName + '%[\\s]*(.)[\\s]*([0-9]+)';
  }

  static patternModifierValue2 (String attributeName) {
    return r'^(.)([0-9]+) %' + attributeName + '%';
  }

  late final List<String> lines;

  MonsterAbilityParser(MonsterAbilityCardModel ability) {
    lines = _extractLines(ability);
  }

  MonsterAbilityAttribute getAttribute (String attributeName) {
    var attribute = MonsterAbilityAttribute(name: attributeName);

    _setBase(attribute);
    _setUpgrade(attribute);

    return attribute;
  }

  void _setBase (MonsterAbilityAttribute attribute) {
    if (lines.isEmpty) {
      return;
    }

    var elementUseRegex = RegExp(patternElementUse());

    for (int i = 0; i < lines.length; i++) {
      var line = lines[i];

      var elementUse = elementUseRegex.firstMatch(line) != null;
      if (elementUse) {
        return;
      }

      var (value, modifier) = _getValue(attribute, line);
      if (value != null) {
        attribute.baseModifier = modifier;
        attribute.baseValue = value;

        return;
      }
    }
  }

  void _setUpgrade (MonsterAbilityAttribute attribute) {
    if (lines.isEmpty) {
      return;
    }

    int? value;
    bool modifier = false;
    String? elementType;

    for (int i = lines.length - 1; i >= 0; i--) {
      var line = lines[i];

      if (value == null) {
        (value, modifier) = _getValue(attribute, line);
        continue;
      }

      elementType = _getElementUseType(line);
      if (elementType != null) {
        break;
      }
    }

    if (elementType == null || value == null) {
      return;
    }

    attribute.upgradeElement = elementMap[elementType];
    attribute.upgradeElementAny = elementType == 'any';
    attribute.upgradeValue = value;
    attribute.upgradeModifier = modifier;
  }

  String? _getElementUseType(String line) {
    var match = RegExp(patternElementUse()).firstMatch(line);

    if (match == null) {
      return null;
    }
    return match.group(1);
  }

  (int?, bool) _getValue (MonsterAbilityAttribute attribute, String line) {
    var regexBase = RegExp(patternBaseValue(attribute.name));
    var regexModifier1 = RegExp(patternModifierValue1(attribute.name));
    var regexModifier2 = RegExp(patternModifierValue2(attribute.name));

    RegExpMatch? match;
    int? value = null;
    String? modifierType = null;

    if ((match = regexBase.firstMatch(line)) != null) {
      value = int.parse(match!.group(1)!);
    } else if ((match = regexModifier1.firstMatch(line)) != null) {
      modifierType = match!.group(1);
      value = int.parse(match.group(2)!);
    } else if ((match = regexModifier2.firstMatch(line)) != null) {
      modifierType = match!.group(1);
      value = int.parse(match.group(2)!);
    }

    if (modifierType == '-' && value != null)  {
      value *= -1;
    }

    var modifier = modifierType != null && !line.contains('instead');

    return (value, modifier);
  }

  List<String> _extractLines (MonsterAbilityCardModel ability) {
    return ability.lines
      .map((line) {
        line = line.toLowerCase().trim();

        if ('*^>!'.split('').any((c) => line.startsWith(c))) {
          line = line.substring(1);
        }

        return line;
      })
      .where((line) => line.contains('%'))
      .toList();
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
    var actionStats = ActionStats(attack: false);

    if (_isConditionActive(Condition.regenerate, figure)) {
      handleHealthChange(figure, 1, actionStats);
    }

    var woundValue = _getWoundAmount(figure);
    if (woundValue != 0) {
      handleHealthChange(figure, woundValue, actionStats);
    }
  }

  static void _applyRoundEndEffects(FigureData figure) { }

  static void handleHealthChange(FigureData figure, int initialChange, ActionStats actionStats) {
    if (initialChange == 0) {
      return;
    }

    var amount = initialChange < 0 ?
      _calculateDamage(initialChange, figure, actionStats) :
      _calculateHeal(initialChange, figure);

    amount = _normalizeHealthChangeAmount(amount, figure);

    if (amount == 0) {
      return;
    }

    var command = ChangeHealthCommand(amount, figure.figureId, figure.ownerId);
    var gameState = getIt<GameState>();

    gameState.action(command);
  }

  static int _calculateDamage(int initialAmount, FigureData figure, ActionStats actionStats) {
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

    if (actionStats.attack) {
      amount += _getPoisonAmount(figure);
      amount += _getShieldAmount(figure, actionStats.pierceAmount.value);
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

  static int _getShieldAmount(FigureData figure, int pierceAmount) {
    var owner = figure.getOwner();

    if (pierceAmount < 0) {
      pierceAmount = 0;
    }

    if (owner is Monster) {
      var elite = (figure.state as MonsterInstance).type == MonsterType.elite;
      var monsterStats = StatApplier.getStatTokens(owner, elite);
      var shieldStat = monsterStats['shield'] ?? 0;

      var shieldAmount = _calculateAbilityAttributeValue(shieldStat, 'shield', owner);

      if (pierceAmount > shieldAmount) {
        return 0;
      }

      return shieldAmount - pierceAmount;
    }

    return 0;
  }

  static int _calculateAbilityAttributeValue (int statValue, String attributeName, Monster monster) {
    var attribute = _getAbilityAttribute('shield', monster);

    if (attribute == null) {
      return statValue;
    }

    var upgraded = _tryUseElement(attribute.upgradeElement, attribute.upgradeElementAny);

    var totalBase = attribute.baseModifier ?
      statValue + attribute.baseValue :
      attribute.baseValue;

    if (!upgraded) {
      return totalBase;
    }

    return attribute.upgradeModifier ?
      totalBase + attribute.upgradeValue :
      statValue + attribute.upgradeValue;
  }

  static bool _tryUseElement (Elements? element, bool any) {
    var gameState = getIt<GameState>();

    if (element == null && !any) {
      return false;
    }

    for (var entry in gameState.elementState.entries) {
      var currentElement = entry.key;
      var state = entry.value;
      var isActive = state != ElementState.inert;

      if (isActive && any) {
        gameState.action(UseElementCommand(currentElement));
        return true;
      }

      if (isActive && currentElement == element) {
        gameState.action(UseElementCommand(currentElement));
        return true;
      }
    }

    return false;
  }

  static MonsterAbilityAttribute? _getAbilityAttribute (String attributeName, Monster monster) {
    var ability = _getCurrentMonsterAbility(monster);

    if (ability == null) {
      return null;
    }

    return MonsterAbilityParser(ability)
      .getAttribute(attributeName);
  }

  static MonsterAbilityCardModel? _getCurrentMonsterAbility (Monster monster) {
    var gameState = getIt<GameState>();

    var abilityDeck = gameState
        .currentAbilityDecks
        .firstWhereOrNull((deck) => deck.name == monster.type.deck);

    if (abilityDeck == null || abilityDeck.discardPile.isEmpty) {
      return null;
    }

    return abilityDeck.discardPile.peek;
  }
}
