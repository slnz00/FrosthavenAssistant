import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:frosthaven_assistant/Layout/condition_icon.dart';
import 'package:frosthaven_assistant/Layout/menus/set_character_level_menu.dart';
import 'package:frosthaven_assistant/Layout/menus/set_level_menu.dart';
import 'package:frosthaven_assistant/Layout/monster_box.dart';
import 'package:frosthaven_assistant/Resource/commands/change_stat_commands/change_bless_command.dart';
import 'package:frosthaven_assistant/Resource/commands/change_stat_commands/change_curse_command.dart';
import 'package:frosthaven_assistant/Resource/commands/change_stat_commands/change_xp_command.dart';
import '../../Resource/commands/add_condition_command.dart';
import '../../Resource/commands/change_stat_commands/change_chill_command.dart';
import '../../Resource/commands/change_stat_commands/change_enfeeble_command.dart';
import '../../Resource/commands/change_stat_commands/change_health_command.dart';
import '../../Resource/commands/ice_wraith_change_form_command.dart';
import '../../Resource/commands/remove_condition_command.dart';
import '../../Resource/commands/set_as_summon_command.dart';
import '../../Resource/effect_handler.dart';
import '../../Resource/enums.dart';
import '../../Resource/state/game_state.dart';
import '../../Resource/settings.dart';
import '../../Resource/ui_utils.dart';
import '../../services/service_locator.dart';
import '../counter_button.dart';
import 'action_menu.dart';

class StatusMenu extends StatefulWidget {
  const StatusMenu({
    Key? key,
    required this.actionData
  }) : super(key: key);

  final ActionData actionData;

  ValueNotifier<List<Condition>> get conditions => actionData.conditions;
  ValueNotifier<int> get healthChange => actionData.healthChange;
  ActionStats get actionStats => actionData.stats;

  bool get attack => actionData.attack;
  String get figureId => actionData.figureId;
  String? get monsterId => actionData.monsterId;
  String? get characterId => actionData.characterId;
  String get ownerId => actionData.ownerId;

  //conditions always:
  //stun,
  //immobilize,
  //disarm,
  //wound,
  //muddle,
  //poison,
  //bane,
  //brittle,
  //strengthen,
  //invisible,
  //regenerate,
  //ward;

  //rupture

  //only monsters:

  //only certain character:
  //poison3,
  //poison4,
  //wound2,

  //poison2,

  //dodge (only character's and 'allies' so basically everyone.

  //only characters;
  //chill, ((only certain scenarios/monsters)
  //infect,((only certain scenarios/monsters)
  //impair

  //character:
  // sliders: hp, xp, chill: normal
  //monster:
  // sliders: hp bless, curse: normal

  //monster layout:
  //stun immobilize  disarm  wound
  //muddle poison bane brittle
  //variable: rupture poison 2 OR  rupture, wound2, poison 2-4
  //strengthen invisible regenerate ward

  //character layout
  //same except line 3: infect impair rupture

  @override
  StatusMenuState createState() => StatusMenuState();
}

class StatusMenuState extends State<StatusMenu> {
  final GameState _gameState = getIt<GameState>();

  bool isObjective = false;

  @override
  initState() {
    // at the beginning, all items are shown
    super.initState();

    isObjective = ["Objective", "Escort"].contains(widget.characterId);
  }

  bool isConditionActive(Condition condition, FigureState figure) {
    var conditions = widget.conditions;

    for (var item in conditions.value) {
      if (item == condition) {
        return true;
      }
    }
    return false;
  }

  Widget buildChillButtons(ValueListenable<int> notifier, int maxValue,
      String image, String figureId, String ownerId, double scale) {
    return Row(children: [
      SizedBox(
          width: 40 * scale,
          height: 40 * scale,
          child: InkWell(
              child: Ink(
                  child: Center(
                    child: SizedBox(
                      width: 24 * scale,
                      height: 24 * scale,
                      child: Image.asset('assets/images/psd/sub.png'),
                    ),
                  )
              ),
              onTap: () {
                if (notifier.value > 0) {
                  _gameState.action(ChangeChillCommand(-1, figureId, ownerId));
                  _gameState.action(RemoveConditionCommand(
                      Condition.chill, figureId, ownerId));
                }
                //increment
              })),
      Stack(children: [
        SizedBox(
          width: 30 * scale,
          height: 30 * scale,
          child: Image(
            image: AssetImage(image),
          ),
        ),
        ValueListenableBuilder<int>(
            valueListenable: notifier,
            builder: (context, value, child) {
              String text = notifier.value.toString();
              if (notifier.value == 0) {
                text = "";
              }
              return Positioned(
                  bottom: 0,
                  right: 0,
                  child: Text(text,
                      style: TextStyle(
                          color: Colors.white,
                          height: 0.5,
                          fontSize: 16 * scale,
                          shadows: [
                            Shadow(
                              offset: Offset(1 * scale, 1 * scale),
                              color: Colors.black87,
                              blurRadius: 1 * scale,
                            )
                          ])));
            })
      ]),
      SizedBox(
          width: 40 * scale,
          height: 40 * scale,
          child: InkWell(
            child: Ink(
                child: Center(
                  child: SizedBox(
                    width: 24 * scale,
                    height: 24 * scale,
                    child: Image.asset('assets/images/psd/add.png'),
                  ),
                )
            ),
            onTap: () {
              if (notifier.value < maxValue) {
                _gameState.action(ChangeChillCommand(1, figureId, ownerId));
                _gameState.action(AddConditionCommand(Condition.chill, figureId, ownerId));
              }
              //increment
            },
          )),
    ]);
  }

  Widget buildSummonButton(String figureId, String ownerId, double scale) {
    String imagePath = "assets/images/summon/green.png";
    // enabled = false;
    return ValueListenableBuilder<int>(
        valueListenable: _gameState.commandIndex,
        builder: (context, value, child) {
          Color color = Colors.transparent;
          FigureState? figure = GameMethods.getFigure(ownerId, figureId);
          if (figure == null) {
            return Container();
          }

          bool isActive = (figure as MonsterInstance).roundSummoned != -1;
          if (isActive) {
            color =
                getIt<Settings>().darkMode.value ? Colors.white : Colors.black;
          }

          return Container(
              width: 42 * scale,
              height: 42 * scale,
              padding: EdgeInsets.zero,
              margin: EdgeInsets.all(1 * scale),
              decoration: BoxDecoration(
                  border: Border.all(
                    color: color,
                  ),
                  borderRadius: BorderRadius.all(Radius.circular(30 * scale))),
              child: IconButton(
                  //iconSize: 24,
                  icon: isActive
                      ? Image(
                          height: 24 * scale,
                          filterQuality: FilterQuality.medium,
                          image: AssetImage(imagePath))
                      : Image.asset(
                          filterQuality: FilterQuality.medium,
                          //needed because of the edges
                          height: 24 * scale,
                          width: 24 * scale,
                          imagePath),
                  onPressed: () {
                    if (!isActive) {
                      _gameState
                          .action(SetAsSummonCommand(true, figureId, ownerId));
                    } else {
                      _gameState
                          .action(SetAsSummonCommand(false, figureId, ownerId));
                    }
                  }));
        });
  }

  Widget buildConditionButton(Condition condition, String figureId,
      String ownerId, List<String> immunities, double scale) {
    var actionData = widget.actionData;

    bool enabled = true;
    String suffix = "";
    if (GameMethods.isFrosthavenStyle(null)) {
      suffix = "_fh";
    }
    String imagePath = "assets/images/abilities/${condition.name}.png";
    if (condition.name.contains("character")) {
      imagePath = "assets/images/class-icons/${condition.getName()}.png";
    } else if (suffix.isNotEmpty && hasGHVersion(condition.name)) {
      imagePath = "assets/images/abilities/${condition.getName()}$suffix.png";
    }
    for (var item in immunities) {
      if (condition.name.contains(item.substring(1, item.length - 1))) {
        enabled = false;
      }
      if (item.substring(1, item.length - 1) == "poison" &&
          condition == Condition.infect) {
        enabled = false;
      }
      if (item.substring(1, item.length - 1) == "wound" &&
          condition == Condition.rupture) {
        enabled = false;
      }
      //immobilize or muddle: also chill - doesn't matter: monster can't be chilled and players don't have immunities.
    }
    // enabled = false;
    return ValueListenableBuilder<List<Condition>>(
        valueListenable: actionData.conditions,
        builder: (context, value, child) {
          Color color = Colors.transparent;
          FigureState? figure = GameMethods.getFigure(ownerId, figureId);
          if (figure == null) {
            return Container();
          }
          ListItemData? owner;
          for (var item in _gameState.currentList) {
            if (item.id == ownerId) {
              owner = item;
              break;
            }
          }

          bool isActive = isConditionActive(condition, figure);
          if (isActive) {
            color =
                getIt<Settings>().darkMode.value ? Colors.white : Colors.black;
          }

          bool isCharacter = condition.name.contains("character");
          Color classColor = Colors.transparent;
          if (isCharacter) {
            var characters = GameMethods.getCurrentCharacters();
            classColor = characters
                .where((element) =>
                    element.characterClass.name == condition.getName())
                .first
                .characterClass
                .color;
          }

          return Container(
              width: 42 * scale,
              height: 42 * scale,
              padding: EdgeInsets.zero,
              margin: EdgeInsets.all(1 * scale),
              decoration: BoxDecoration(
                  border: Border.all(
                    color: color,
                  ),
                  borderRadius: BorderRadius.all(Radius.circular(30 * scale))),
              child: IconButton(
                //iconSize: 24,
                icon: enabled
                    ? isActive
                        ? ConditionIcon(
                            condition,
                            24 * scale,
                            owner!,
                            figure,
                            scale: scale,
                          )
                        : isCharacter
                            ? Stack(alignment: Alignment.center, children: [
                                Image(
                                    color: classColor,
                                    colorBlendMode: BlendMode.modulate,
                                    height: 24 * scale,
                                    filterQuality: FilterQuality.medium,
                                    image: const AssetImage(
                                        "assets/images/psd/class-token-bg.png")),
                                Image(
                                    height: 24 * scale * 0.65,
                                    filterQuality: FilterQuality.medium,
                                    image: AssetImage(imagePath)),
                              ])
                            : Image.asset(
                                filterQuality: FilterQuality.medium,
                                //needed because of the edges
                                height: 24 * scale,
                                width: 24 * scale,
                                imagePath)
                    : Stack(
                        alignment: Alignment.center,
                        children: [
                          Positioned(
                              left: 0,
                              top: 0,
                              child: Image(
                                height: 23.1 * scale,
                                filterQuality: FilterQuality.medium,
                                //needed because of the edges
                                image: AssetImage(imagePath),
                              )),
                          Positioned(
                              //should be 19  but there is a clipping issue
                              left: 15.75 * scale,
                              top: 7.35 * scale,
                              child: Image(
                                height: 8.4 * scale,
                                filterQuality: FilterQuality.medium,
                                //needed because of the edges
                                image: const AssetImage(
                                    "assets/images/psd/immune.png"),
                              )),
                        ],
                      ),
                //iconSize: 30,
                onPressed: enabled
                    ? () {
                        var newConditions = [...actionData.conditions.value];

                        if (!isActive) {
                          newConditions.add(condition);
                        } else {
                          newConditions.remove(condition);
                        }

                        actionData.conditions.value = newConditions;
                      }
                    : null,
              ));
        });
  }

  @override
  Widget build(BuildContext context) {
    bool showCustomContent = getIt<Settings>().showCustomContent.value;
    bool hasMireFoot = false;
    bool hasIncarnate = false;
    bool isSummon = (widget.monsterId == null &&
        widget.characterId !=
            widget
                .figureId); //hack - should have monsterBox send summon data instead
    for (var item in _gameState.currentList) {
      if (item.id == "Mirefoot" && showCustomContent) {
        hasMireFoot = true;
      }
      if (item.id == "Incarnate" && showCustomContent) {
        hasIncarnate = true;
      }
    }

    String name = "";
    String ownerId = "";
    if (widget.monsterId != null) {
      name = widget.monsterId!; //this is no good
      ownerId = widget.monsterId!;
    } else if (widget.characterId != null) {
      name = widget.characterId!;
      ownerId = name;
    }

    String figureId = widget.figureId;
    FigureState? figure = GameMethods.getFigure(ownerId, figureId);
    if (figure == null) {
      return Container();
    }

    List<String> immunities = [];
    Monster? monster;
    bool isIceWraith = false;
    bool isElite = false;
    if (figure is MonsterInstance) {
      name = (figure).name;

      if (widget.monsterId != null) {
        for (var item in _gameState.currentList) {
          if (item.id == widget.monsterId) {
            monster = item as Monster;
            name = "${monster.type.display} ${figure.standeeNr.toString()}";
            if (monster.type.deck == "Ice Wraith") {
              isIceWraith = true;
            }
            if (figure.type == MonsterType.normal) {
              immunities =
                  monster.type.levels[monster.level.value].normal!.immunities;
            } else if (figure.type == MonsterType.elite) {
              immunities =
                  monster.type.levels[monster.level.value].elite!.immunities;
              isElite = true;
            } else if (figure.type == MonsterType.boss) {
              immunities =
                  monster.type.levels[monster.level.value].boss!.immunities;
            }
          }
        }
      }
    }
    //has to be summon

    //get id and owner Id
    Character? character;
    if (widget.characterId != null) {
      for (var item in _gameState.currentList) {
        if (item.id == widget.characterId) {
          character = item as Character;
        }
      }
    }

    double scale = 1;
    if (!isPhoneScreen(context)) {
      scale = 1.5;
      if (isLargeTablet(context)) {
        scale = 2;
      }
    }

    int nrOfCharacters = GameMethods.getCurrentCharacterAmount();

    return Container(
        width: 340 * scale,
        height: 220 * scale +
            30 * scale +
            ((widget.attack)
                ? 40 * scale
                : 0) +
            ((hasIncarnate && widget.monsterId != null && !isSummon)
                ? 40 * scale
                : 0),
        decoration: BoxDecoration(
          image: DecorationImage(
            colorFilter: ColorFilter.mode(
                Colors.black.withOpacity(0.8), BlendMode.dstATop),
            image: AssetImage(getIt<Settings>().darkMode.value
                ? 'assets/images/bg/dark_bg.png'
                : 'assets/images/bg/white_bg.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          SizedBox(
              height: 28 * scale,
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Text("$name (${widget.attack ? "Attack" : "Passive"})",
                        style: getTitleTextStyle(scale)),
                    if (figure is MonsterInstance)
                      ValueListenableBuilder<int>(
                          valueListenable: getIt<GameState>().updateList,
                          builder: (context, value, child) {
                            //handle case when health is changed to zero: don't instantiate monster box
                            if(GameMethods.getFigure(ownerId, figureId) == null) {
                              return Container();
                            }

                            return Container(
                                height: 28 * scale,
                                margin: EdgeInsets.only(top: 2 * scale),
                                child: MonsterBox(
                                    figureId: figureId,
                                    ownerId: ownerId,
                                    displayStartAnimation: "",
                                    blockInput: true,
                                    scale: scale * 0.9));
                          }),
                    if (isIceWraith)
                      TextButton(
                          clipBehavior: Clip.hardEdge,
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.only(right: 20 * scale),
                          ),
                          onPressed: () {
                            setState(() {
                              _gameState.action(IceWraithChangeFormCommand(
                                  isElite, ownerId, figureId));
                            });
                          },
                          child: Text("                     Switch Form",
                              style: TextStyle(
                                fontSize: 14 * scale,
                                color: Colors.blue,
                              )))
                  ])),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            ValueListenableBuilder<int>(
                valueListenable: _gameState.commandIndex,
                builder: (context, value, child) {
                  ModifierDeck deck = _gameState.modifierDeck;
                  if (widget.monsterId != null) {
                    for (var item in _gameState.currentList) {
                      if (item.id == widget.monsterId) {
                        if (item is Monster && item.isAlly) {
                          deck = _gameState.modifierDeckAllies;
                        }
                      }
                    }
                  }
                  bool hasXp = false;
                  bool isObjective = false;
                  if (widget.characterId != null && !isSummon) {
                    hasXp = true;
                    for (var item in _gameState.currentList) {
                      if (item.id == widget.characterId) {
                        if ((item as Character).characterClass.name ==
                                "Objective" ||
                            (item).characterClass.name == "Escort") {
                          hasXp = false;
                          isObjective = true;
                        }
                      }
                    }
                  }

                  bool canBeCursed = true;
                  for (var item in immunities) {
                    if (item.substring(1, item.length - 1) == "curse") {
                      canBeCursed = false;
                    }
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CounterButton(
                          figure.health,
                          null,
                          figure.maxHealth.value,
                          "assets/images/abilities/heal.png",
                          false,
                          Colors.red,
                          callback: (int change) {
                            widget.healthChange.value += change;
                            return change;
                          }, figureId: figureId, ownerId: ownerId, scale: scale),
                      const SizedBox(height: 2),
                      hasXp
                          ? CounterButton(
                              (figure as CharacterState).xp,
                              ChangeXPCommand(0, figureId, ownerId),
                              900,
                              "assets/images/psd/xp.png",
                              false,
                              Colors.blue,
                              figureId: figureId,
                              ownerId: ownerId,
                              scale: scale)
                          : Container(),
                      SizedBox(height: hasXp ? 2 : 0),
                      widget.attack && !isObjective
                          ? CounterButton(
                          widget.actionStats.pierceAmount,
                          null,
                          999,
                          "assets/images/abilities/pierce.png",
                          true,
                          Colors.white,
                          callback: (int change) {
                            var pierceAmount = widget.actionStats.pierceAmount.value;

                            if (pierceAmount + change < 0) {
                              change = pierceAmount * -1;
                            }

                            widget.actionStats.pierceAmount.value += change;
                            return change;
                          },
                          figureId: figureId, ownerId: ownerId, scale: scale)
                          : Container(),
                      SizedBox(height: widget.attack ? 2 : 0),
                      widget.characterId != null && !isObjective
                          ? CounterButton(
                          widget.attack ? widget.actionStats.characterShieldModifier : _gameState.characterShields,
                          null,
                          999,
                          "assets/images/abilities/shield_fh.png",
                          true,
                          Colors.white,
                          getValue: () {
                            var figure = GameMethods.getFigure(ownerId, figureId);

                            if (figure == null || widget.characterId == null) {
                              return 0;
                            }

                            var fullId = figure.getFullId();
                            var baseId = figure.getBaseId();

                            var shieldMap = _gameState.characterShields.value;
                            var baseShieldAmount = shieldMap[baseId] ?? 0;
                            var shieldAmount = baseShieldAmount + (shieldMap[fullId] ?? 0);

                            if (widget.attack) {
                              shieldAmount += widget.actionStats.characterShieldModifier.value;
                            }

                            return shieldAmount;
                          },
                          callback: (int change) {
                            var figure = GameMethods.getFigure(ownerId, figureId);

                            if (figure == null || widget.characterId == null) {
                              return 0;
                            }

                            var fullId = figure.getFullId();
                            var baseId = figure.getBaseId();

                            var shieldMap = _gameState.characterShields.value;
                            var baseShieldAmount = shieldMap[baseId] ?? 0;
                            var shieldAmount = shieldMap[fullId] ?? 0;
                            var modifier = widget.actionStats.characterShieldModifier.value;
                            var totalShieldAmount = baseShieldAmount + shieldAmount + modifier;

                            if (widget.attack) {
                              change = totalShieldAmount + change < 0 ? totalShieldAmount * -1 : change;

                              widget.actionStats.characterShieldModifier.value = modifier + change;
                            }
                            else {
                              change = shieldAmount + change < 0 ? shieldAmount * -1 : change;

                              shieldMap[fullId] = shieldAmount + change;
                              _gameState.characterShields.value = Map<String,int>.from(shieldMap);
                            }

                            return change;
                          },
                          figureId: figureId, ownerId: ownerId, scale: scale)
                          : Container(),
                      SizedBox(height: widget.characterId != null ? 2 : 0),
                      SizedBox(
                          height:
                              widget.characterId != null || isSummon ? 2 : 0),
                      widget.monsterId != null
                          ? CounterButton(
                              deck.blesses,
                              ChangeBlessCommand(0, figureId, ownerId),
                              10,
                              "assets/images/abilities/bless.png",
                              true,
                              Colors.white,
                              figureId: figureId,
                              ownerId: ownerId,
                              scale: scale)
                          : Container(),
                      SizedBox(height: widget.monsterId != null ? 2 : 0),
                      widget.monsterId != null && canBeCursed
                          ? CounterButton(
                              deck.curses,
                              ChangeCurseCommand(0, figureId, ownerId),
                              10,
                              "assets/images/abilities/curse.png",
                              true,
                              Colors.white,
                              figureId: figureId,
                              ownerId: ownerId,
                              scale: scale)
                          : Container(),
                      widget.monsterId != null && hasIncarnate
                          ? CounterButton(
                              deck.enfeebles,
                              ChangeEnfeebleCommand(0, figureId, ownerId),
                              10,
                              "assets/images/abilities/enfeeble.png",
                              true,
                              Colors.white,
                              figureId: figureId,
                              ownerId: ownerId,
                              scale: scale)
                          : Container(),
                      if (showCustomContent)
                        buildChillButtons(
                            figure.chill,
                            12,
                            //technically you can have infinite, but realistically not so much
                            "assets/images/abilities/chill.png",
                            figureId,
                            ownerId,
                            scale),
                      SizedBox(
                          height:
                              widget.monsterId != null && canBeCursed ? 2 : 0),
                      Row(
                        children: [
                          SizedBox(
                            width: 42 * scale,
                            height: 42 * scale,
                            child: IconButton(
                              icon: Image.asset('assets/images/psd/skull.png'),
                              //iconSize: 10,
                              onPressed: () {
                                Navigator.pop(context);
                                _gameState.action(ChangeHealthCommand(
                                    -figure.health.value, figureId, ownerId));
                              },
                            ),
                          ),
                          SizedBox(
                              width: 42 * scale,
                              height: 42 * scale,
                              child: IconButton(
                                icon: Image.asset(
                                    colorBlendMode: BlendMode.multiply,
                                    'assets/images/psd/level.png'),
                                //iconSize: 10,
                                onPressed: () {
                                  if (figure is CharacterState) {
                                    openDialog(
                                      context,
                                      SetCharacterLevelMenu(character: character!),
                                    ).then((val) {
                                      _gameState.syncCharacterShields();
                                    });
                                  } else {
                                    openDialog(
                                      context,
                                      SetLevelMenu(
                                        monster: monster,
                                        figure: figure,
                                        characterId: widget.characterId
                                      ),
                                    );
                                  }
                                },
                              )),
                          if (!isObjective)
                            Text(figure.level.value.toString(),
                                style: TextStyle(
                                    fontSize: 14 * scale,
                                    color: Colors.white,
                                    shadows: [
                                      Shadow(
                                        offset: Offset(1 * scale, 1 * scale),
                                        color: Colors.black87,
                                        blurRadius: 1 * scale,
                                      )
                                    ])),
                        ],
                      )
                    ],
                  );
                }),
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  height: 2 * scale,
                ),
                //const Text("Status", style: TextStyle(fontSize: 18)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    buildConditionButton(
                        Condition.stun, figureId, ownerId, immunities, scale),
                    buildConditionButton(Condition.immobilize, figureId,
                        ownerId, immunities, scale),
                    buildConditionButton(
                        Condition.disarm, figureId, ownerId, immunities, scale),
                    buildConditionButton(
                        Condition.wound, figureId, ownerId, immunities, scale),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    buildConditionButton(
                        Condition.muddle, figureId, ownerId, immunities, scale),
                    buildConditionButton(
                        Condition.poison, figureId, ownerId, immunities, scale),
                    buildConditionButton(
                        Condition.bane, figureId, ownerId, immunities, scale),
                    buildConditionButton(Condition.brittle, figureId, ownerId,
                        immunities, scale),
                  ],
                ),
                widget.characterId != null || isSummon
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (showCustomContent)
                            buildConditionButton(Condition.infect, figureId,
                                ownerId, immunities, scale),
                          if (!isSummon)
                            buildConditionButton(Condition.impair, figureId,
                                ownerId, immunities, scale),
                          if (showCustomContent)
                            buildConditionButton(Condition.rupture, figureId,
                                ownerId, immunities, scale)
                        ],
                      )
                    : !hasMireFoot
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (showCustomContent)
                                buildConditionButton(Condition.poison2,
                                    figureId, ownerId, immunities, scale),
                              if (showCustomContent)
                                buildConditionButton(Condition.rupture,
                                    figureId, ownerId, immunities, scale),
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              buildConditionButton(Condition.wound2, figureId,
                                  ownerId, immunities, scale),
                              buildConditionButton(Condition.poison2, figureId,
                                  ownerId, immunities, scale),
                              buildConditionButton(Condition.poison3, figureId,
                                  ownerId, immunities, scale),
                              buildConditionButton(Condition.poison4, figureId,
                                  ownerId, immunities, scale),
                              buildConditionButton(Condition.rupture, figureId,
                                  ownerId, immunities, scale),
                            ],
                          ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    buildConditionButton(Condition.strengthen, figureId,
                        ownerId, immunities, scale),
                    buildConditionButton(Condition.invisible, figureId, ownerId,
                        immunities, scale),
                    buildConditionButton(Condition.regenerate, figureId,
                        ownerId, immunities, scale),
                    buildConditionButton(
                        Condition.ward, figureId, ownerId, immunities, scale),
                    if (showCustomContent)
                      buildConditionButton(Condition.dodge, figureId, ownerId,
                          immunities, scale),
                  ],
                ),
                if (monster != null)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (nrOfCharacters > 0)
                        buildConditionButton(Condition.character1, figureId,
                            ownerId, immunities, scale),
                      if (nrOfCharacters > 1)
                        buildConditionButton(Condition.character2, figureId,
                            ownerId, immunities, scale),
                      if (nrOfCharacters > 2)
                        buildConditionButton(Condition.character3, figureId,
                            ownerId, immunities, scale),
                      if (nrOfCharacters > 3)
                        buildConditionButton(Condition.character4, figureId,
                            ownerId, immunities, scale),
                      buildSummonButton(figureId, ownerId, scale)
                    ],
                  ),
              ],
            ),
          ]),
        ]));
  }
}
