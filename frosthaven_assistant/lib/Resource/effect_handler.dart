import 'dart:math';

import 'package:built_collection/built_collection.dart';
import 'package:collection/collection.dart';
import 'package:frosthaven_assistant/Model/MonsterAbility.dart';
import 'package:frosthaven_assistant/Resource/commands/imbue_element_command.dart';
import 'package:frosthaven_assistant/Resource/line_builder/stat_applier.dart';
import 'package:frosthaven_assistant/Resource/state/game_state.dart';

import '../Layout/menus/action_menu.dart';
import '../Model/monster.dart';
import '../services/service_locator.dart';
import 'commands/change_stat_commands/change_health_command.dart';
import 'commands/remove_condition_command.dart';
import 'commands/use_element_command.dart';
import 'enums.dart';

class FigureData {
  final String ownerId;
  final String figureId;
  late final FigureState state;

  ListItemData? getOwner() {
    for (var item in getIt<GameState>().currentList) {
      if (item.id == ownerId) {
        return item;
      }
    }

    return null;
  }

  String getBaseId() {
    return state.getBaseId();
  }

  String getFullId() {
    return state.getFullId();
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
  static final List<String> persistentAttributes = ["shield"];

  static final Map<String, Elements> elementMap = {
    'air': Elements.air,
    'dark': Elements.dark,
    'earth': Elements.earth,
    'fire': Elements.fire,
    'ice': Elements.ice,
    'light': Elements.light,
  };

  static patternElementActivate() {
    var elements = elementMap.keys.toList().join('|');
    return r'%(' + elements + '|any)%\$';
  }

  static patternElementUse() {
    return r'%([^%]+)%%use%';
  }

  static patternSpecialAbility() {
    return r'^special (\d+)$';
  }

  static patternBaseValue(String attributeName) {
    return r'%' + attributeName + '%[\\s]*([0-9]+)';
  }

  static patternModifierValue1(String attributeName) {
    return r'%' + attributeName + '%[\\s]*(.)[\\s]*([0-9]+)';
  }

  static patternModifierValue2(String attributeName) {
    return r'^(.)([0-9]+) %' + attributeName + '%';
  }

  static String? getElementUseType(String line) {
    var match = RegExp(patternElementUse()).firstMatch(line);

    if (match == null) {
      return null;
    }
    return match.group(1);
  }

  late final List<String> lines;

  MonsterAbilityParser(MonsterAbilityCardModel ability, MonsterStatsModel? bossStats) {
    var specialAbility = _getSpecialAbility(ability, bossStats);

    lines = _extractLines(specialAbility ?? ability);
  }

  (List<Elements>, bool) getActivateElements() {
    List<Elements> elements = [];
    bool anyElement = false;

    var elementActivateRegex = RegExp(patternElementActivate());
    var elementUseRegex = RegExp(patternElementUse());

    for (int i = 0; i < lines.length; i++) {
      var line = lines[i];
      var prevLine = i > 0 ? lines[i-1] : null;
      var parts = line.split(" ");

      for (var part in parts) {
        var match = elementActivateRegex.firstMatch(part);
        var elementType = match?.group(1);
        if (elementType == null) {
          continue;
        }

        if (elementType == 'any') {
          anyElement = true;
          continue;
        }

        var element = elementMap[elementType];
        if (element != null) {
          elements.add(element);
        }
      }

      var useMatch = prevLine != null ? elementUseRegex.firstMatch(prevLine) : null;
      var isConvert = elements.isNotEmpty && useMatch != null;

      if (isConvert) {
        elements.clear();
        anyElement = false;
      }
    }

    return (elements, anyElement);
  }

  (List<Elements>, bool) getUseElements() {
    List<Elements> elements = [];
    bool anyElement = false;

    var elementUseRegex = RegExp(patternElementUse());
    var elementActivateRegex = RegExp(patternElementActivate());

    for (int i = 0; i < lines.length; i++) {
      var line = lines[i];
      var nextLine = i < lines.length - 1 ? lines[i+1] : null;

      var match = elementUseRegex.firstMatch(line);
      var activateMatch = nextLine != null ? elementActivateRegex.firstMatch(nextLine) : null;

      var isConvert = activateMatch != null;
      if (isConvert) {
        continue;
      }

      var elementType = match?.group(1);
      if (elementType == null) {
        continue;
      }

      if (elementType == 'any') {
        anyElement = true;
        continue;
      }

      var element = elementMap[elementType];
      if (element != null) {
        elements.add(element);
      }
    }

    return (elements, anyElement);
  }

  (Elements?, bool, Elements?, bool) getConvertElement() {
    Elements? from;
    bool fromAny = false;
    Elements? to;
    bool toAny = false;

    var elementUseRegex = RegExp(patternElementUse());
    var elementActivateRegex = RegExp(patternElementActivate());

    for (int i = 0; i < lines.length - 1; i++) {
      var line = lines[i];
      var nextLine = lines[i + 1];

      var useMatch = elementUseRegex.firstMatch(line);
      var activateMatch = elementActivateRegex.firstMatch(nextLine);

      var fromType = useMatch?.group(1);
      var toType = activateMatch?.group(1);

      if (fromType == null || toType == null) {
        continue;
      }

      if (fromType == 'any') {
        fromAny = true;
      } else {
        from = elementMap[fromType];
      }

      if (toType == 'any') {
        toAny = true;
      } else {
        to = elementMap[toType];
      }
    }

    return (from, fromAny, to, toAny);
  }

  MonsterAbilityAttribute getAttribute(String attributeName) {
    var attribute = MonsterAbilityAttribute(name: attributeName);

    attribute.baseModifier =
        MonsterAbilityParser.persistentAttributes.contains(attributeName);

    _setBase(attribute);
    _setUpgrade(attribute);

    return attribute;
  }

  void _setBase(MonsterAbilityAttribute attribute) {
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

  void _setUpgrade(MonsterAbilityAttribute attribute) {
    if (lines.isEmpty) {
      return;
    }

    int? value;
    bool modifier = false;
    String? elementType;

    for (int i = lines.length - 1; i >= 0; i--) {
      var line = lines[i];

      if (line.contains('....')) {
        value = null;
        continue;
      }

      if (value == null) {
        (value, modifier) = _getValue(attribute, line);
        continue;
      }

      elementType = getElementUseType(line);
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

  (int?, bool) _getValue(MonsterAbilityAttribute attribute, String line) {
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

    if (modifierType == '-' && value != null) {
      value *= -1;
    }

    var modifier = modifierType != null && !line.contains('instead');

    return (value, modifier);
  }

  List<String> _extractLines(MonsterAbilityCardModel ability) {
    var lines = ability.lines
        .map((line) {
          line = line.toLowerCase().trim();

          if ('*^>!'.split('').any((c) => line.startsWith(c))) {
            line = line.substring(1);
          }

          return line;
        })
        .where((line) => line.contains('%') || line.contains('....'))
        .toList();

    var elementTypes = ['any', ...elementMap.keys];

    for (var pos in ability.graphicPositional) {
      if (elementTypes.contains(pos.gfx)) {
        lines.add('%${pos.gfx}%');
      }
    }

    return lines;
  }

  MonsterAbilityCardModel? _getSpecialAbility(MonsterAbilityCardModel ability, MonsterStatsModel? bossStats) {
    if (bossStats == null) {
      return null;
    }

    var regexUseSpecial = RegExp(patternSpecialAbility());
    var firstLine = ability.lines[0].trim().toLowerCase();

    RegExpMatch? match;
    int? specialValue;

    if ((match = regexUseSpecial.firstMatch(firstLine)) != null) {
      specialValue = int.parse(match!.group(1)!);
    }

    if (specialValue == null) {
      return null;
    }

    List<String>? lines;

    if (specialValue == 1) {
      lines = bossStats.special1;
    }
    if (specialValue == 2) {
      lines = bossStats.special2;
    }

    if (lines == null) {
      return null;
    }

    return MonsterAbilityCardModel('tmp', 0, false, 1, lines, '', const []);
  }
}

class EffectHandler {
  static final _random = new Random();

  static final List<Condition> _poisonConditions = [
    Condition.poison4,
    Condition.poison3,
    Condition.poison2,
    Condition.poison,
  ];

  static final List<Condition> _woundConditions = [
    Condition.wound2,
    Condition.wound,
  ];

  static void handleTurnStart(ListItemData data) {
    var gameState = getIt<GameState>();

    var roundStarted = gameState.isRoundFlagSet(data.id, Flags.roundStart);
    if (roundStarted) {
      return;
    }

    gameState.setRoundFlag(data.id, Flags.roundStart);

    if (data is Monster) {
      _handleInstances(data, data.monsterInstances, _applyTurnStartEffects);

      var hasInstances = data.monsterInstances.isNotEmpty;
      var notAllStunned = !_allInstancesAreStunned(data, data.monsterInstances);

      if (hasInstances && notAllStunned) {
        _handleElements(data);
      }
    }
    if (data is Character) {
      var character = FigureData(data.id, data.id);

      _handleElements(data);
      _handleInstances(
          data, data.characterState.summonList, _applyTurnStartEffects);
      _applyTurnStartEffects(character);
    }
  }

  static bool _allInstancesAreStunned(
      ListItemData owner, BuiltList<MonsterInstance> instances) {
    for (var instance in instances) {
      var figure = FigureData(owner.id, instance.getId());

      if (!_isConditionActive(Condition.stun, figure)) {
        return false;
      }
    }

    return true;
  }

  static void handleRoundEnd() {
    var gameState = getIt<GameState>();

    for (var item in gameState.currentList) {
      if (item is Character) {
        var character = FigureData(item.id, item.id);

        _handleInstances(
            item, item.characterState.summonList, _applyRoundEndEffects);
        _applyRoundEndEffects(character);
      } else if (item is Monster) {
        _handleInstances(item, item.monsterInstances, _applyRoundEndEffects);
      }
    }
  }

  static void _handleInstances(ListItemData owner,
      BuiltList<MonsterInstance> instances, Function(FigureData) handler) {
    for (var instance in instances) {
      var figure = FigureData(owner.id, instance.getId());
      handler(figure);
    }
  }

  static void _applyTurnStartEffects(FigureData figure) {
    var actionStats = ActionStats(attack: false);

    if (_isConditionActive(Condition.strengthen, figure) &&
        _isConditionActive(Condition.muddle, figure)) {
      _removeCondition(Condition.strengthen, figure);
      _removeCondition(Condition.muddle, figure);
    }

    if (_isConditionActive(Condition.regenerate, figure)) {
      handleHealthChange(figure, 1, actionStats);
    }

    var woundValue = _getWoundAmount(figure);
    if (woundValue != 0) {
      handleHealthChange(figure, woundValue, actionStats);
    }
  }

  static void _applyRoundEndEffects(FigureData figure) {
    var actionStats = ActionStats(attack: false);

    if (_isConditionActive(Condition.bane, figure)) {
      _removeCondition(Condition.bane, figure);

      handleHealthChange(figure, -10, actionStats);
    }
  }

  static void handleHealthChange(
      FigureData figure, int initialChange, ActionStats actionStats) {
    var amount = initialChange <= 0
        ? _calculateDamage(initialChange, figure, actionStats)
        : _calculateHeal(initialChange, figure);

    amount = _normalizeHealthChangeAmount(amount, figure);

    if (amount == 0) {
      return;
    }

    var command = ChangeHealthCommand(amount, figure.figureId, figure.ownerId);
    var gameState = getIt<GameState>();

    gameState.action(command);
  }

  static void _handleElements(ListItemData data) {
    var gameState = getIt<GameState>();

    if (data is Monster) {
      var ability = _getCurrentMonsterAbility(data);
      var bossStats = _getBossStats(data);
      if (ability == null) {
        return;
      }

      var parser = MonsterAbilityParser(ability, bossStats);
      var (useElements, useAny) = parser.getUseElements();
      var (activateElements, activateAny) = parser.getActivateElements();
      var (convertFrom, convertFromAny, convertTo, convertToAny) = parser.getConvertElement();

      _convertElement(data.id, convertFrom, convertFromAny, convertTo, convertToAny);

      for (var element in useElements) {
        _useElement(data.id, element);
      }
      if (useAny) {
        _useAnyElement(data.id);
      }

      for (var element in activateElements) {
        _activateElement(element);
      }
      if (activateAny) {
        _activateAnyElement();
      }

      gameState.syncCharacterRoundFlags();
    }
  }

  static int _calculateDamage(
      int initialAmount, FigureData figure, ActionStats actionStats) {
    var amount = initialAmount;

    if (initialAmount == 0 && !actionStats.attack) {
      return 0;
    }

    if (_isConditionActive(Condition.ward, figure) &&
        _isConditionActive(Condition.brittle, figure)) {
      _removeCondition(Condition.ward, figure);
      _removeCondition(Condition.brittle, figure);
    }

    if (actionStats.attack) {
      amount += _getPoisonAmount(figure);
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
      amount += _getShieldAmount(figure, actionStats.pierceAmount.value,
          actionStats.characterShieldModifier.value);
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

    var hasBrittle = _isConditionActive(Condition.brittle, figure);
    if (hasBrittle) {
      _removeCondition(Condition.brittle, figure);
    }

    var hasBane = _isConditionActive(Condition.bane, figure);
    if (hasBane) {
      _removeCondition(Condition.bane, figure);
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

  static int _normalizeHealthChangeAmount(int amount, FigureData figure) {
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
    var command =
        RemoveConditionCommand(condition, figure.figureId, figure.ownerId);

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

  static int _getShieldAmount(FigureData figure, int pierceAmount, int characterShieldModifier) {
    var owner = figure.getOwner();

    if (pierceAmount < 0) {
      pierceAmount = 0;
    }

    if (owner is Character) {
      var gameState = getIt<GameState>();
      var baseShield =
          gameState.characterShields.value[figure.getBaseId()] ?? 0;
      var shieldAmount = baseShield +
          (gameState.characterShields.value[figure.getFullId()] ?? 0);

      shieldAmount += characterShieldModifier - pierceAmount;

      if (shieldAmount < 0) {
        return 0;
      }
      return shieldAmount;
    }

    if (owner is Monster) {
      var elite = (figure.state as MonsterInstance).type == MonsterType.elite;
      var monsterStats = StatApplier.getStatTokens(owner, elite);
      var shieldStat = monsterStats['shield'] ?? 0;

      var shieldAmount =
          _calculateAbilityAttributeValue(shieldStat, 'shield', owner) -
              pierceAmount;

      if (shieldAmount < 0) {
        return 0;
      }
      return shieldAmount;
    }

    return 0;
  }

  static bool _isElementUsed(
      String characterId, Elements? element, bool anyElement) {
    var gameState = getIt<GameState>();

    if (anyElement) {
      return gameState.isRoundFlagSet(characterId, Flags.anyElement);
    }

    var flag = element != null ? Flags.elements[element] : null;
    if (flag == null) {
      return false;
    }

    return gameState.isRoundFlagSet(characterId, flag);
  }

  static int _calculateAbilityAttributeValue(
      int statValue, String attributeName, Monster monster) {
    var attribute = _getAbilityAttribute('shield', monster);

    if (attribute == null) {
      return statValue;
    }

    var upgraded = _isElementUsed(
        monster.id, attribute.upgradeElement, attribute.upgradeElementAny);

    var totalBase = attribute.baseModifier
        ? statValue + attribute.baseValue
        : attribute.baseValue;

    if (!upgraded) {
      return totalBase;
    }

    return attribute.upgradeModifier
        ? totalBase + attribute.upgradeValue
        : statValue + attribute.upgradeValue;
  }

  static void _activateElement(Elements element) {
    var gameState = getIt<GameState>();

    var isFull = gameState.elementState.entries.any(
        (entry) => (entry.key == element && entry.value == ElementState.full));

    if (isFull) {
      return;
    }

    gameState.action(ImbueElementCommand(element, false));
  }

  static void _activateAnyElement() {
    var gameState = getIt<GameState>();

    var element = _getRandomElement([ElementState.inert, ElementState.half]);
    if (element == null) {
      return;
    }

    gameState.action(ImbueElementCommand(element, false));
  }

  static void _convertElement(String characterId, Elements? from, bool fromAny, Elements? to, bool toAny) {
    if ((from == null && !fromAny) || (to == null && !toAny)) {
      return;
    }

    var used = from != null ? _useElement(characterId, from) : _useAnyElement(characterId);

    if (!used) {
      return;
    }

    if (to != null) {
      _activateElement(to);
    } else {
      _activateAnyElement();
    }
  }

  static bool _useAnyElement(String characterId) {
    var gameState = getIt<GameState>();

    var element = _getRandomElement([ElementState.half, ElementState.full]);
    if (element == null) {
      return false;
    }

    gameState.action(UseElementCommand(element));
    gameState.setRoundFlag(characterId, Flags.anyElement, sync: false);

    return true;
  }

  static bool _useElement(String characterId, Elements element) {
    var gameState = getIt<GameState>();

    var isActive = gameState.elementState.entries.any(
        (entry) => (entry.key == element && entry.value != ElementState.inert));

    if (!isActive) {
      return false;
    }

    gameState.action(UseElementCommand(element));
    gameState.setRoundFlag(characterId, Flags.elements[element]!, sync: false);

    return true;
  }

  static Elements? _getRandomElement(List<ElementState> states) {
    var gameState = getIt<GameState>();

    var elements = gameState.elementState.entries
        .where((entry) => states.contains(entry.value))
        .map((entry) => entry.key)
        .toList();

    if (elements.isEmpty) {
      return null;
    }

    return elements[_random.nextInt(elements.length)];
  }

  static MonsterAbilityAttribute? _getAbilityAttribute(String attributeName, Monster monster) {
    var ability = _getCurrentMonsterAbility(monster);
    var bossStats = _getBossStats(monster);

    if (ability == null) {
      return null;
    }

    return MonsterAbilityParser(ability, bossStats).getAttribute(attributeName);
  }

  static MonsterAbilityCardModel? _getCurrentMonsterAbility(Monster monster) {
    var gameState = getIt<GameState>();

    var abilityDeck = gameState.currentAbilityDecks
        .firstWhereOrNull((deck) => deck.name == monster.type.deck);

    if (abilityDeck == null || abilityDeck.discardPile.isEmpty) {
      return null;
    }

    return abilityDeck.discardPile.peek;
  }

  static MonsterStatsModel? _getBossStats(Monster monster) {
    return monster.type.levels[monster.level.value].boss;
  }
}
