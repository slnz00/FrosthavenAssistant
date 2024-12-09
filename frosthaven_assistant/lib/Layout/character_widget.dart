import 'dart:math';

import 'package:flutter/material.dart';
import 'package:frosthaven_assistant/Layout/menus/action_menu.dart';
import 'package:frosthaven_assistant/Layout/menus/numpad_menu.dart';
import 'package:frosthaven_assistant/Layout/menus/status_menu.dart';
import 'package:frosthaven_assistant/Resource/commands/set_init_command.dart';
import 'package:frosthaven_assistant/Resource/scaling.dart';
import 'package:frosthaven_assistant/services/network/network.dart';
import '../Resource/color_matrices.dart';
import '../Resource/commands/change_stat_commands/change_xp_command.dart';
import '../Resource/commands/next_turn_command.dart';
import '../Resource/enums.dart';
import '../Resource/state/game_state.dart';
import '../Resource/settings.dart';
import '../Resource/ui_utils.dart';
import '../services/service_locator.dart';
import 'condition_icon.dart';
import 'health_wheel_controller.dart';
import 'menus/add_summon_menu.dart';
import 'monster_box.dart';

class CharacterWidget extends StatefulWidget {
  static final Map<String, int> localCharacterInitChanges =
      {}; //if it's been changed locally then it's not hidden
  final String characterId;
  final int? initPreset;
  final VoidCallback onInitNumberProvided;

  const CharacterWidget(
      {required this.characterId, required this.initPreset, Key? key, required this.onInitNumberProvided})
      : super(key: key);

  @override
  CharacterWidgetState createState() => CharacterWidgetState();
}

class CharacterWidgetState extends State<CharacterWidget> with SingleTickerProviderStateMixin {
  final GameState _gameState = getIt<GameState>();
  late bool isCharacter = true;
  final _initTextFieldController = TextEditingController();
  late List<MonsterInstance> lastList = [];
  late Character character;
  final focusNode = FocusNode();

  late AnimationController _xpAnimationController;
  late Animation<Color?> _xpColor;

  String getInitiativeText () {
    return _initTextFieldController.text;
  }

  void focusInitiativeInput () {
    focusNode.requestFocus();
  }

  void _textFieldControllerListener() {
    for (var item in _gameState.currentList) {
      if (item is Character) {
        if (item.id == character.id) {
          if (_initTextFieldController.value.text.isNotEmpty &&
              _initTextFieldController.value.text !=
                  character.characterState.initiative.value.toString() &&
              _initTextFieldController.value.text.isNotEmpty &&
              _initTextFieldController.value.text != "??") {
            int? init = int.tryParse(_initTextFieldController.value.text);
            if (init != null && init != 0) {
              CharacterWidget.localCharacterInitChanges[character.id] = init;
              _gameState.action(SetInitCommand(character.id, init));
            }
          }
          break;
        }
      }
    }
  }

  @override
  void dispose() {
    _initTextFieldController.removeListener(_textFieldControllerListener);
    _xpAnimationController.dispose();

    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    _xpAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 0),
      reverseDuration: const Duration(milliseconds: 200)
    );

    _xpColor = ColorTween(
      begin: Colors.blue,
      end: Colors.white,
    ).animate(CurvedAnimation(
      parent: _xpAnimationController,
      curve: Curves.easeOut,
    ));

    for (var item in _gameState.currentList) {
      if (item.id == widget.characterId && item is Character) {
        character = item;
      }
    }
    lastList = character.characterState.summonList.toList();

    if (widget.initPreset != null) {
      _initTextFieldController.text = widget.initPreset.toString();
    }
    _initTextFieldController.addListener(_textFieldControllerListener);

    if (character.characterClass.name == "Objective" ||
        character.characterClass.name == "Escort") {
      isCharacter = false;
      //widget.character.characterState.initiative = widget.initPreset!;
    }
    if (isCharacter) {
      _initTextFieldController.clear();
    }
    if (_gameState.roundState.value == RoundState.playTurns) {
      CharacterWidget.localCharacterInitChanges.clear();
    }
  }

  List<Widget> createConditionList(double scale) {
    List<Widget> conditions = [];
    for (int i = conditions.length;
        i < character.characterState.conditions.value.length;
        i++) {
      conditions.add(ConditionIcon(
        character.characterState.conditions.value[i],
        16,
        character,
        character.characterState,
        scale: scale,
      ));
    }
    return conditions;
  }

  Widget summonsButton(double scale) {
    return SizedBox(
        width: 50 * scale,
        height: 50 * scale,
        child: IconButton(
          padding: EdgeInsets.zero,
          icon: Image.asset(
              height: 30 * scale,
              fit: BoxFit.fitHeight,
              color: Colors.white24,
              colorBlendMode: BlendMode.modulate,
              'assets/images/psd/add.png'),
          onPressed: () {
            openDialog(
              context,
              AddSummonMenu(
                character: character,
              ),
            );
          },
        ));
  }

  Widget buildMonsterBoxGrid(double scale) {
    String displayStartAnimation = "";

    if (lastList.length < character.characterState.summonList.length) {
      //find which is new - always the last one
      displayStartAnimation =
          character.characterState.summonList.last.getId();
    }

    final generatedChildren = List<Widget>.generate(
        character.characterState.summonList.length,
        (index) => AnimatedSize(
              //not really needed now
              key: Key(index.toString()),
              duration: const Duration(milliseconds: 300),
              child: MonsterBox(
                  key: Key(
                      character.characterState.summonList[index].getId()),
                  figureId: character
                          .characterState.summonList[index].name +
                      character.characterState.summonList[index].gfx +
                      character.characterState.summonList[index].standeeNr
                          .toString(),
                  ownerId: character.id,
                  displayStartAnimation: displayStartAnimation,
                  blockInput: false,
                  scale: scale),
            ));
    lastList = character.characterState.summonList.toList();
    return Wrap(
      runSpacing: 2.0 * scale,
      spacing: 2.0 * scale,
      children: generatedChildren,
    );
  }

  void resetInitiativeText () {
    var init = character.characterState.initiative.value;
    var settings = getIt<Settings>();

    bool secret = (settings.server.value || settings.client.value == ClientState.connected) &&
        (CharacterWidget.localCharacterInitChanges[character.id] != init);

    if (_initTextFieldController.text != character.characterState.initiative.value.toString() &&
        character.characterState.initiative.value != 0) {

      if (secret || settings.hideAllInitiatives.value) {
        _initTextFieldController.text = "??";
      } else {
        _initTextFieldController.text = character.characterState.initiative.value.toString();
      }
    }
  }

  Widget buildInitiativeWidget(BuildContext context, double scale,
      double scaledHeight, Shadow shadow, bool frosthavenStyle) {
    return Column(children: [
      Container(
        margin: EdgeInsets.only(top: scaledHeight / 6, left: 10 * scale),
        child: Image(
          //fit: BoxFit.contain,
          height: scaledHeight * 0.1,
          image: const AssetImage("assets/images/init.png"),
        ),
      ),
      ValueListenableBuilder<int>(
          valueListenable: character.characterState.initiative,
          builder: (context, value, child) {
            var init = character.characterState.initiative.value;

            bool secret = (getIt<Settings>().server.value ||
                    getIt<Settings>().client.value == ClientState.connected) &&
                (CharacterWidget.localCharacterInitChanges[character.id] != init);

            if (_initTextFieldController.text !=
                    character.characterState.initiative.value.toString() &&
                character.characterState.initiative.value != 0 &&
                (_initTextFieldController.text.isNotEmpty || secret)) {
              //handle secret if originating from other device

              if (secret || getIt<Settings>().hideAllInitiatives.value) {
                _initTextFieldController.text = "??";
              } else {
                _initTextFieldController.text =
                    character.characterState.initiative.value.toString();

                CharacterWidget.localCharacterInitChanges.remove(character.id);
              }
            }

            if (_gameState.roundState.value == RoundState.playTurns &&
                isCharacter) {
              CharacterWidget.localCharacterInitChanges.clear();
              _initTextFieldController.clear();
            }

            /*if (isCharacter && _gameState.commandIndex.value >= 0 &&
                                                _gameState.commands[_gameState.commandIndex.value] is DrawCommand) {
                                              _initTextFieldController.clear();
                                            }*/

            if (_gameState.roundState.value == RoundState.chooseInitiative &&
                character.characterState.health.value > 0) {
              return Container(
                margin:
                    EdgeInsets.only(left: 11 * scale, top: scaledHeight * 0.11),
                height: scaledHeight * 0.5,
                //33 * scale,
                width: 25 * scale,
                padding: EdgeInsets.zero,
                alignment: Alignment.topCenter,
                child: Focus(
                  onFocusChange: (hasFocus) {
                    if (!hasFocus && _initTextFieldController.text.isNotEmpty) {
                      widget.onInitNumberProvided();

                      if (getIt<Settings>().hideAllInitiatives.value) {
                        _initTextFieldController.text = "??";
                      }
                    }
                    if (!hasFocus && _initTextFieldController.text.isEmpty) {
                      resetInitiativeText();
                    }
                  },

                  child: TextField(
                      focusNode: focusNode,

                      //scrollPadding: EdgeInsets.zero,
                      onTap: () {
                        //clear on enter focus
                        if (_initTextFieldController.text != "??") {
                          _initTextFieldController.clear();
                        }

                        if (getIt<Settings>().softNumpadInput.value) {
                          openDialog(
                              context,
                              NumpadMenu(
                                controller: _initTextFieldController,
                                maxLength: 2,
                              ));
                        }
                      },
                      onChanged: (String str) {
                        //close soft keyboard on 2 chars entered
                        if (str.length == 2) {
                          FocusManager.instance.primaryFocus?.unfocus();
                        }
                      },

                      //expands: true,
                      textAlign: TextAlign.center,
                      cursorColor: Colors.white,
                      maxLength: 2,
                      style: TextStyle(
                          height: 1,
                          //quick fix for web-phone disparity.
                          fontFamily: frosthavenStyle ? 'GermaniaOne' : 'Pirata',
                          color: Colors.white,
                          fontSize: 24 * scale,
                          shadows: [shadow]),
                      decoration: const InputDecoration(
                        isDense: true,
                        //this is what fixes the height issue
                        counterText: '',
                        contentPadding: EdgeInsets.zero,
                        enabledBorder: UnderlineInputBorder(
                          borderRadius: BorderRadius.zero,
                          borderSide:
                              BorderSide(width: 0, color: Colors.transparent),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderRadius: BorderRadius.zero,
                          borderSide:
                              BorderSide(width: 0, color: Colors.transparent),
                        ),
                        // border: UnderlineInputBorder(
                        //   borderSide:
                        //      BorderSide(color: Colors.pink),
                        // ),
                      ),
                      controller: _initTextFieldController,
                      keyboardType: getIt<Settings>().softNumpadInput.value
                          ? TextInputType.none
                          : TextInputType.number),
                ),
              );
            } else {
              if (isCharacter) {
                _initTextFieldController.clear();
              }
              return Container(
                  height: 33 * scale,
                  width: 25 * scale,
                  margin: EdgeInsets.only(left: 10 * scale),
                  child: Text(
                    character.characterState.health.value > 0 &&
                            character.characterState.initiative.value > 0
                        ? character.characterState.initiative.value.toString()
                        : "",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontFamily: frosthavenStyle ? 'GermaniaOne' : 'Pirata',
                        color: Colors.white,
                        fontSize: 24 * scale,
                        shadows: [shadow]),
                  ));
            }
          }),
    ]);
  }

  SweepGradient buildGradiantBackground(List<Color> colors) {
    int nrOfColorEntries = colors.length * 3 + 1;

    List<Color> endList = [];
    for (int i = 0; i < 3; i++) {
      for (Color color in colors) {
        endList.add(color);
      }
    }
    endList.add(colors[0]);

    List<double> stops = [];
    stops.add(0);
    for (int i = 1; i < nrOfColorEntries - 1; i++) {
      stops.add(i / nrOfColorEntries);
    }
    stops.add(1);

    return SweepGradient(
        center: FractionalOffset.bottomRight,
        transform: const GradientRotation(2),
        tileMode: TileMode.mirror,
        colors: endList,

        /*[
          Colors.yellow,
          Colors.purple,
          Colors.teal,
          Colors.white24,
          Colors.yellow,
          Colors.purple,
          Colors.teal,
          Colors.white24,
          Colors.yellow,
          Colors.purple,
          Colors.teal,
          Colors.white24,
          Colors.yellow,
        ],*/
        stops: stops
        /* [
          0,
          1 / 13,
          2 / 13,
          3 / 13,
          4 / 13,
          5 / 13,
          6 / 13,
          7 / 13,
          8 / 13,
          9 / 13,
          10 / 13,
          12 / 13,
          1
        ]*/
        );
  }

  Widget buildWithHealthWheel() {
    return HealthWheelController(
        figureId: widget.characterId,
        ownerId: widget.characterId,
        child: PhysicalShape(
            color: character.turnState == TurnsState.current
                ? Colors.tealAccent
                : Colors.transparent,
            shadowColor: Colors.black,
            elevation: 8,
            clipper: const ShapeBorderClipper(shape: RoundedRectangleBorder()),
            child: buildInternal(context)));
  }

  Widget buildInternal(BuildContext context) {
    double scale = getScaleByReference(context);
    double scaledHeight = 60 * scale;
    bool frosthavenStyle = GameMethods.isFrosthavenStyle(null);

    var shadow = Shadow(
      offset: Offset(1 * scale, 1 * scale),
      color: Colors.black87,
      blurRadius: 1 * scale,
    );

    return SizedBox(
        width: getMainListWidth(context),
        // 408 * scale,
        height: 60 * scale,
        child: Stack(
          //alignment: Alignment.centerLeft,
          children: [
            Container(
              //background
              margin: EdgeInsets.all(2 * scale),
              width: 408 * scale,
              height: 58 * scale,
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black45,
                    blurRadius: 4 * scale,
                    offset: Offset(2 * scale, 4 * scale), // Shadow position
                  ),
                ],
                image: DecorationImage(
                    fit: BoxFit.fill,
                    colorFilter: character.characterClass.name ==
                                "Shattersong" ||
                            character.characterClass.name == "Rimehearth"
                        ? ColorFilter.mode(
                            character.characterClass.color, BlendMode.softLight)
                        : ColorFilter.mode(
                            character.characterClass.colorSecondary,
                            BlendMode.color),
                    image: const AssetImage(
                        "assets/images/psd/character-bar.png")),
                shape: BoxShape.rectangle,
                //color: character.characterClass.name == "Shattersong"? null : character.characterClass.colorSecondary,
              ),
              child: Container(
                  decoration: BoxDecoration(
                      backgroundBlendMode:
                          (character.characterClass.name == "Shattersong" ||
                                  character.characterClass.name == "Rimehearth")
                              ? BlendMode.multiply
                              : null,
                      gradient: (character.characterClass.name == "Shattersong")
                          ? buildGradiantBackground([
                              Colors.yellow,
                              Colors.purple,
                              Colors.teal,
                              Colors.white24
                            ])
                          : character.characterClass.name == "Rimehearth"
                              ? buildGradiantBackground([
                                  character.characterClass.colorSecondary,
                                  character.characterClass.color
                                ])
                              : null)),
            ),
            Row(
              children: [
                Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.6),
                          spreadRadius: 4,
                          blurRadius: 13.0 * scale,
                          //offset: Offset(1* settings.userScalingBars.value, 1* settings.userScalingBars.value), // changes position of shadow
                        ),
                      ],
                    ),
                    margin: EdgeInsets.only(
                        left: 26 * scale, top: 5 * scale, bottom: 5 * scale),
                    child: character.characterClass.name == "Shattersong"
                        ? ShaderMask(
                            shaderCallback: (bounds) {
                              return LinearGradient(
                                  transform: const GradientRotation(pi * -0.6),
                                  colors: [
                                    Color(int.parse("ff759a9d", radix: 16)),
                                    Color(int.parse("ffa0a8ac", radix: 16)),
                                      Color(int.parse("ff759a9d", radix: 16)),
                                  ],
                                  stops: const [
                                    0,
                                    0.2,
                                    1
                                  ]).createShader(bounds);
                            },
                            blendMode: BlendMode.srcATop,
                            child: Image.asset(
                              "assets/images/class-icons/${character.characterClass.name}.png",
                              height: scaledHeight * 0.6,
                              fit: BoxFit.contain,
                            ),
                          )
                        : Image(
                            fit: BoxFit.contain,
                            height: scaledHeight * 0.6,
                            color: isCharacter
                                ? character.characterClass.color
                                : null,
                            filterQuality: FilterQuality.medium,
                            image: AssetImage(
                              "assets/images/class-icons/${character.characterClass.name}.png",
                            ),
                            width: scaledHeight * 0.6,
                          )),
                buildInitiativeWidget(
                    context, scale, scaledHeight, shadow, frosthavenStyle),
                Column(
                    //mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    //align children to the left
                    children: [
                      Container(
                        margin:
                            EdgeInsets.only(top: 10 * scale, left: 10 * scale),
                        child: ValueListenableBuilder<String>(
                            valueListenable: character.characterState.display,
                            // widget.data.monsterInstances,
                            builder: (context, value, child) {
                              return Text(
                                character.characterState.display.value,
                                style: TextStyle(
                                    fontFamily: frosthavenStyle
                                        ? 'GermaniaOne'
                                        : 'Pirata',
                                    color: Colors.white,
                                    fontSize: frosthavenStyle
                                        ? 15 * scale
                                        : 16 * scale,
                                    shadows: [shadow]),
                              );
                            }),
                      ),
                      ValueListenableBuilder<int>(
                          valueListenable: _gameState.commandIndex,
                          //not working?
                          builder: (context, value, child) {
                            return Container(
                                margin: EdgeInsets.only(left: 10 * scale),
                                child: HealthWheelController(
                                    figureId: widget.characterId,
                                    ownerId: widget.characterId,
                                    child: Row(children: [
                                      Image(
                                        fit: BoxFit.contain,
                                        height: scaledHeight * 0.2,
                                        image: const AssetImage(
                                            "assets/images/blood.png"),
                                      ),
                                      Text(
                                        frosthavenStyle
                                            ? '${character.characterState.health.value.toString()}/${character.characterState.maxHealth.value.toString()}'
                                            : '${character.characterState.health.value.toString()} / ${character.characterState.maxHealth.value.toString()}',
                                        style: TextStyle(
                                            fontFamily: frosthavenStyle
                                                ? 'GermaniaOne'
                                                : 'Pirata',
                                            color: Colors.white,
                                            fontSize: frosthavenStyle
                                                ? 16 * scale
                                                : 16 * scale,
                                            shadows: [shadow]),
                                      ),
                                      //add conditions here
                                      ValueListenableBuilder<List<Condition>>(
                                          valueListenable: character
                                              .characterState.conditions,
                                          builder: (context, value, child) {
                                            return Row(
                                              children:
                                                  createConditionList(scale),
                                            );
                                          }),
                                    ])));
                          })
                    ])
              ],
            ),
            isCharacter
                ? Positioned(
                    top: 12 * scale,
                    left: 310 * scale,
                    child: ValueListenableBuilder<int>(
                      valueListenable: character.characterState.xp,
                      builder: (context, value, child) {
                        return AnimatedBuilder(
                          animation: _xpAnimationController,
                          builder: (context, child) {
                            return Row(
                              children: [
                                Image(
                                  height: 16 * scale,
                                  color: _xpColor.value,
                                  colorBlendMode: BlendMode.modulate,
                                  image: const AssetImage("assets/images/psd/xp.png"),
                                ),
                                SizedBox(width: character.characterState.xp.value <= 9 ? 3 * scale : 1 * scale),
                                Text(
                                  character.characterState.xp.value.toString(),
                                  style: TextStyle(
                                      fontFamily: frosthavenStyle
                                          ? 'GermaniaOne'
                                          : 'Pirata',
                                      color: _xpColor.value,
                                      fontSize: 14 * scale,
                                      shadows: [shadow]),
                                )
                              ],
                            );
                          }
                        );
                      }
                    )
                  )
                : Container(),
            isCharacter
                ? Positioned(
                    top: 21 * scale,
                    left: 285 * scale,
                    child: Row(
                      children: [
                        Image(
                          height: 16 * scale,
                          color: Colors.white,
                          colorBlendMode: BlendMode.modulate,
                          image: const AssetImage("assets/images/abilities/shield_fh.png"),
                        ),
                        ValueListenableBuilder<dynamic>(
                            valueListenable: _gameState.characterShields,
                            builder: (context, value, child) {
                              var figure = GameMethods.getFigure(widget.characterId, widget.characterId);
                              var fullId = figure?.getFullId();
                              var baseId = figure?.getBaseId();
                              var shieldMap = _gameState.characterShields.value;

                              var shieldAmount = (fullId != null ? shieldMap[fullId] : null) ?? 0;
                              var baseShieldAmount = (fullId != null ? shieldMap[baseId] : null) ?? 0;
                              var value = baseShieldAmount + shieldAmount;

                              return Text(
                                value.toString(),
                                style: TextStyle(
                                    fontFamily: frosthavenStyle
                                        ? 'GermaniaOne'
                                        : 'Pirata',
                                    color: Colors.white,
                                    fontSize: 14 * scale,
                                    shadows: [shadow]),
                              );
                            }),
                      ],
                    ))
                : Container(),
            isCharacter
                ? Positioned(
                    top: 30 * scale,
                    left: 310 * scale,
                    child: Row(
                      children: [
                        Image(
                          height: 12.0 * scale,
                          image:
                              const AssetImage("assets/images/psd/level.png"),
                        ),
                        SizedBox(width: 3 * scale),
                        ValueListenableBuilder<int>(
                            valueListenable: character.characterState.level,
                            builder: (context, value, child) {
                              return Text(
                                character.characterState.level.value.toString(),
                                style: TextStyle(
                                    fontFamily: frosthavenStyle
                                        ? 'GermaniaOne'
                                        : 'Pirata',
                                    color: Colors.white,
                                    fontSize: 14 * scale,
                                    shadows: [shadow]),
                              );
                            }),
                      ],
                    ))
                : Container(),
            isCharacter
                ? Positioned(
                    right: 19 * scale,
                    top: 4 * scale,
                    child: summonsButton(scale),
                  )
                : Container(),
            isCharacter
                ? Positioned(
                top: 10 * scale,
                left: 305 * scale,
                child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onDoubleTap: () {
                      var addXp = ChangeXPCommand(1, widget.characterId, widget.characterId);

                      if (_xpAnimationController.isAnimating) {
                        _xpAnimationController.reset();
                      }
                      _xpAnimationController.forward()
                          .then((_) => Future.delayed(const Duration(milliseconds: 100)))
                          .then((_) => _xpAnimationController.reverse());

                      _gameState.action(addXp);
                    },
                    child: SizedBox(
                      width: 40 * scale,
                      height: 40 * scale,
                    )
                )
            ) : Container(),
            if (character.characterState.health.value > 0)
              InkWell(
                  onTap: () {
                    if (_gameState.roundState.value ==
                        RoundState.chooseInitiative) {
                      //if in choose mode - focus the input or open the soft numpad if that option is on
                      if (getIt<Settings>().softNumpadInput.value == true) {
                        openDialog(
                            context,
                            NumpadMenu(
                              controller: _initTextFieldController,
                              maxLength: 2,
                            ));
                      } else {
                        //focus on
                        focusNode.requestFocus();
                      }
                    } else {
                      getIt<GameState>().action(TurnDoneCommand(character.id));
                    }
                    //if in choose mode - focus the input or open the soft numpad if that option is on
                    //else: mark as done
                  },
                  child: SizedBox(
                    height: 60 * scale,
                    width: 70 * scale,
                  )),
          ],
        ));
  }

  @override
  Widget build(BuildContext context) {
    for (var item in _gameState.currentList) {
      if (item.id == widget.characterId && item is Character) {
        character = item;
      }
    }

    return GestureDetector(
        onTap: () {
          //open stats menu
          openDialog(
            context,
            ActionMenu(figureId: character.id, characterId: character.id),
          );
        },
        behavior: HitTestBehavior.translucent,
        child: ValueListenableBuilder<dynamic>(
            valueListenable: getIt<GameState>().updateList,
            builder: (context, value, child) {
              bool notGrayScale = character.characterState.health.value != 0 &&
                  (character.turnState != TurnsState.done ||
                      getIt<GameState>().roundState.value ==
                          RoundState.chooseInitiative);
              double scale = getScaleByReference(context);
              return Column(mainAxisSize: MainAxisSize.max, children: [
                Container(
                  //padding: EdgeInsets.zero,
                  // color: Colors.amber,
                  //height: 50,
                  margin: EdgeInsets.only(
                      left: 3.2 * scale, right: 3.2 * scale),
                  width: getMainListWidth(context) - 6.4 * scale,
                  child: ValueListenableBuilder<int>(
                      valueListenable: getIt<GameState>().killMonsterStandee,
                      // widget.data.monsterInstances,
                      builder: (context, value, child) {
                        return buildMonsterBoxGrid(scale);
                      }),
                ),
                ColorFiltered(
                    colorFilter: notGrayScale
                        ? ColorFilter.matrix(identity)
                        : ColorFilter.matrix(grayScale),
                    child: _gameState.roundState.value ==
                            RoundState.chooseInitiative
                        ? buildInternal(context)
                        : buildWithHealthWheel())
              ]);
            }));
  }
}
