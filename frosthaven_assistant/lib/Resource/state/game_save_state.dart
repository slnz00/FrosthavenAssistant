part of 'game_state.dart';

class GameSaveState {
  String getState() {
    return _savedState!;
  }

  String? _savedState;

  void save() {
    _savedState = getIt<GameState>().toString();
  }

  void _loadLootDeck(var data) {
    var lootDeckData = data["lootDeck"];
    LootDeck state = LootDeck.fromJson(lootDeckData);
    getIt<GameState>()._lootDeck = state;
  }

  void _loadModifierDeck(String identifier, var data) {
    //modifier deck
    String name = "";
    if (identifier == 'modifierDeckAllies') {
      name = "allies";
    }
    var modifierDeckData = data[identifier];
    ModifierDeck state = ModifierDeck(name);
    List<ModifierCard> newDrawList = [];
    List drawPile = modifierDeckData["drawPile"] as List;
    for (var item in drawPile) {
      String gfx = item["gfx"];
      if (gfx == "curse") {
        newDrawList.add(ModifierCard(CardType.curse, gfx));
      } else if (gfx == "enfeeble") {
        newDrawList.add(ModifierCard(CardType.enfeeble, gfx));
      } else if (gfx == "bless") {
        newDrawList.add(ModifierCard(CardType.bless, gfx));
      } else if (gfx.contains("nullAttack") || gfx.contains("doubleAttack")) {
        newDrawList.add(ModifierCard(CardType.multiply, gfx));
      } else {
        newDrawList.add(ModifierCard(CardType.add, gfx));
      }
    }
    List<ModifierCard> newDiscardList = [];
    for (var item in modifierDeckData["discardPile"] as List) {
      String gfx = item["gfx"];
      if (gfx == "curse") {
        newDiscardList.add(ModifierCard(CardType.curse, gfx));
      } else if (gfx == "enfeeble") {
        newDiscardList.add(ModifierCard(CardType.enfeeble, gfx));
      } else if (gfx == "bless") {
        newDiscardList.add(ModifierCard(CardType.bless, gfx));
      } else if (gfx.contains("nullAttack") || gfx.contains("doubleAttack")) {
        newDiscardList.add(ModifierCard(CardType.multiply, gfx));
        state._needsShuffle = true;
      } else {
        newDiscardList.add(ModifierCard(CardType.add, gfx));
      }
    }
    state._drawPile.clear();
    state._discardPile.clear();
    state._drawPile.setList(newDrawList);
    state._discardPile.setList(newDiscardList);
    state._cardCount.value = state._drawPile.size();

    if (modifierDeckData.containsKey("curses")) {
      int curses = modifierDeckData['curses'];
      state._curses.value = curses;
    }
    if (modifierDeckData.containsKey("enfeebles")) {
      int enfeebles = modifierDeckData['enfeebles'];
      state._enfeebles.value = enfeebles;
    }
    if (modifierDeckData.containsKey("blesses")) {
      int blesses = modifierDeckData['blesses'];
      state._blesses.value = blesses;
    }

    if (modifierDeckData.containsKey('badOmen')) {
      state._badOmen.value = modifierDeckData["badOmen"] as int;
    }
    if (modifierDeckData.containsKey('addedMinusOnes')) {
      state._addedMinusOnes.value = modifierDeckData["addedMinusOnes"] as int;
    }

    if (identifier == 'modifierDeck') {
      getIt<GameState>()._modifierDeck = state;
    } else {
      getIt<GameState>()._modifierDeckAllies = state;
    }
  }

  Future<void> load() async {
    if (_savedState != null) {
      GameState gameState = getIt<GameState>();
      try {
        var data = json.decode(_savedState!) as Map<String, dynamic>;

        gameState._level.value = data['level'] as int;
        gameState._scenario.value = data['scenario']; // as String;
        if (data.containsKey('toastMessage')) {
          gameState._toastMessage.value = data['toastMessage']; // as String;
        }

        if (data.containsKey('scenarioSectionsAdded')) {
          List<dynamic> scenarioSectionsAdded =
              data['scenarioSectionsAdded'] as List;
          gameState._scenarioSectionsAdded.clear();
          for (var item in scenarioSectionsAdded) {
            gameState._scenarioSectionsAdded.add(item);
          }
        }

        if (data.containsKey('scenarioSpecialRules')) {
          var scenarioSpecialRulesList = data['scenarioSpecialRules'] as List;
          gameState._scenarioSpecialRules.clear();
          for (Map<String, dynamic> item in scenarioSpecialRulesList) {
            gameState._scenarioSpecialRules.add(SpecialRule.fromJson(item));
          }
        }
        gameState._currentCampaign.value = data['currentCampaign'];
        //TODO: currentCampaign does not update properly (because changing it is not a command)
        gameState._round.value = data['round'] as int;
        gameState._roundState.value = RoundState.values[data['roundState']];
        gameState._solo.value = data['solo']
            as bool; //TODO: does not update properly (because changing it is not a command)

        //main list
        var list = data['currentList'] as List;
        gameState._currentList.clear();
        List<ListItemData> newList = [];
        for (Map<String, dynamic> item in list) {
          if (item["characterClass"] != null) {
            Character character = Character.fromJson(item);
            //is character
            newList.add(character);
          } else if (item["type"] != null) {
            //is monster
            Monster monster = Monster.fromJson(item);
            newList.add(monster);
          }
        }
        gameState._currentList = newList;

        var unlockedClassesList = data['unlockedClasses'] as List;
        gameState._unlockedClasses.clear();
        for (String item in unlockedClassesList) {
          gameState._unlockedClasses.add(item);
        }

        //ability decks
        var decks = data['currentAbilityDecks'] as List;
        gameState._currentAbilityDecks.clear();
        for (Map<String, dynamic> item in decks) {
          MonsterAbilityState state = MonsterAbilityState(item["name"]);

          List<MonsterAbilityCardModel> newDrawList = [];
          List drawPile = item["drawPile"] as List;
          for (var item in drawPile) {
            int nr = item["nr"];
            for (var card in state.drawPile.getList()) {
              if (card.nr == nr) {
                newDrawList.add(card);
                break;
              }
            }
          }
          List<MonsterAbilityCardModel> newDiscardList = [];
          for (var item in item["discardPile"] as List) {
            int nr = item["nr"];
            for (var card in state.drawPile.getList()) {
              if (card.nr == nr) {
                newDiscardList.add(card);
                break;
              }
            }
          }
          if (item.containsKey("lastRoundDrawn")) {
            state._lastRoundDrawn = item["lastRoundDrawn"];
          }

          state.drawPile.clear();
          state.discardPile.clear();
          state.drawPile.setList(newDrawList);
          state.discardPile.setList(newDiscardList);
          gameState._currentAbilityDecks.add(state);
        }

        _loadModifierDeck('modifierDeck', data);
        _loadModifierDeck('modifierDeckAllies', data);
        _loadLootDeck(data);

        //this is not really a setting, but a scenario command?
        if (data["showAllyDeck"] != null) {
          gameState.showAllyDeck.value = data["showAllyDeck"];
        }

        if (data.containsKey("characterShields")) {
          gameState.characterShields.value = Map<String,int>.from(
            data["characterShields"].map((key, value) => MapEntry(key, value as int))
          );
        }

        if (data.containsKey("characterRoundFlags")) {
          gameState.characterRoundFlags.value = Map<String, String>.from(
            data["characterRoundFlags"].map((key, value) => MapEntry(key, value.toString()))
          );
        }

        //////elements
        Map elementData = data['elementState'];
        //Map<Elements, ElementState> newMap = {};
        gameState._elementState.clear();
        gameState._elementState[Elements.fire] =
            ElementState.values[elementData[Elements.fire.index.toString()]];
        gameState._elementState[Elements.ice] =
            ElementState.values[elementData[Elements.ice.index.toString()]];
        gameState._elementState[Elements.air] =
            ElementState.values[elementData[Elements.air.index.toString()]];
        gameState._elementState[Elements.earth] =
            ElementState.values[elementData[Elements.earth.index.toString()]];
        gameState._elementState[Elements.light] =
            ElementState.values[elementData[Elements.light.index.toString()]];
        gameState._elementState[Elements.dark] =
            ElementState.values[elementData[Elements.dark.index.toString()]];
      } catch (e) {
        if (kDebugMode) {
          print(e.toString());
        }
      }
    }
  }

  Future<void> saveToDisk() async {
    if (_savedState == null) {
      save();
    }
    const sharedPrefsKey = 'gameState';
    try {
      final prefs = await SharedPreferences.getInstance();
      // save
      await prefs.setString(sharedPrefsKey, _savedState!);
    } catch (error) {
      if (kDebugMode) {
        print(error);
      }
    }
  }

  Future<void> loadFromDisk() async {
    //have to call after init or element state overridden

    const sharedPrefsKey = 'gameState';
    bool hasError = false;
    bool isWaiting = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      _savedState = prefs.getString(sharedPrefsKey);
      hasError = false;
    } catch (error) {
      hasError = true;
    }
    isWaiting = false;

    if (_savedState != null) {
      load();
    } else {
      save();
    }
  }

  Future<void> loadFromData(String data) async {
    //have to call after init or element state overridden
    _savedState = data;
    load();
  }
}
