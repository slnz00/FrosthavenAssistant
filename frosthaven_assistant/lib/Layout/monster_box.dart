import 'package:animated_widgets/animated_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animation_progress_bar/flutter_animation_progress_bar.dart';
import 'package:frosthaven_assistant/Layout/condition_icon.dart';
import 'package:frosthaven_assistant/Layout/health_wheel_controller.dart';
import 'package:frosthaven_assistant/Layout/menus/action_menu.dart';
import 'package:frosthaven_assistant/Resource/effect_handler.dart';
import 'package:frosthaven_assistant/Resource/state/game_state.dart';
import 'package:frosthaven_assistant/services/service_locator.dart';
import '../Resource/color_matrices.dart';
import '../Resource/enums.dart';
import '../Resource/settings.dart';
import '../Resource/ui_utils.dart';
import 'dart:math' as math;

class MonsterBox extends StatefulWidget {
  final String figureId;
  final String ownerId;
  final String displayStartAnimation;
  final bool blockInput;
  final double scale;

  const MonsterBox({Key? key,
    required this.figureId,
    required this.ownerId,
    required this.displayStartAnimation,
    required this.blockInput,
    required this.scale})
      : super(key: key);

  static const double conditionSize = 14;

  static double getBoxBaseWidth(ListItemData? owner, MonsterInstance instance) {
    double width = 47;
    int shieldValue = getShieldValue(owner, instance);

    if (shieldValue > 0) {
      width += 16;
    }

    return width;
  }

  static double getWidth(double scale, ListItemData? owner, MonsterInstance instance) {
    double width = getBoxBaseWidth(owner, instance);
    width += conditionSize * instance.conditions.value.length / 2;
    if (instance.conditions.value.length % 2 != 0) {
      width += conditionSize / 2;
    }
    width = width * scale;
    return width;
  }

  static int getShieldValue(ListItemData? owner, MonsterInstance instance) {
    var gameState = getIt<GameState>();

    if (owner is Monster) {
      Settings settings = getIt<Settings>();

      if (!settings.showShieldOnMonsters.value) {
        return 0;
      }

      return EffectHandler.calculateMonsterStat('shield', owner, instance);
    }

    var baseShield = gameState.characterShields.value[instance.getBaseId()] ?? 0;
    var shield = gameState.characterShields.value[instance.getFullId()] ?? 0;

    return baseShield + shield;
  }

  @override
  MonsterBoxState createState() => MonsterBoxState();
}

class MonsterBoxState extends State<MonsterBox> {
  late MonsterInstance data;
  late String instanceId;
  late ListItemData? owner;

  final GameState _gameState = getIt<GameState>();

  @override
  void initState() {
    super.initState();
    data = GameMethods.getFigure(widget.ownerId, widget.figureId) as MonsterInstance;
    owner = GameMethods.getListItem(widget.ownerId);
    instanceId = data.getId();
  }

  List<Widget> createConditionList(double scale) {
    List<Widget> list = [];
    for (var condition in data.conditions.value) {
      for (var item in getIt<GameState>().currentList) {
        if (item.id == widget.ownerId) {
          list.add(ConditionIcon(
            condition,
            MonsterBox.conditionSize,
            item,
            data,
            scale: scale,
          ));
          break;
        }
      }
    }
    return list;
  }

  String? getMonsterId() {
    for (var item in getIt<GameState>().currentList) {
      if (item is Monster) {
        if (item.id == data.name) {
          return item.id;
        }
      }
    }
    return null;
  }

  Widget buildInternal(double scale, double width, Color color) {
    String imagePath = "assets/images/tombstone.png";
    if (data.type == MonsterType.summon) {
      imagePath = "assets/images/summon/${data.gfx}.png";
    } else {
      if (data.roundSummoned != -1) {
        imagePath = "assets/images/summon/green.png";
      }
    }
    String standeeNr = "";
    if (data.standeeNr > 0) {
      standeeNr = data.standeeNr.toString();
    }
    Color? borderColor = color;
    if (data.type == MonsterType.summon) {
      borderColor = Colors.blue;
    }
    BlendMode blendMode = BlendMode.hue;
    if (color == Colors.red) {
      blendMode = BlendMode.modulate;
    }
    if (color == Colors.yellow) {
      borderColor = null;
    }
    if (data.ally) {
      color = Colors.white;
      borderColor = Colors.green;
      imagePath = "assets/images/summon/green.png";
    }

    var shadow = Shadow(
      offset: Offset(0.4 * scale, 0.4 * scale),
      color: Colors.black87,
      blurRadius: 1 * scale,
    );

    bool ownerIsCurrent = true;
    for (var item in getIt<GameState>().currentList) {
      if (item.id == widget.ownerId) {
        if (item.turnState == TurnsState.done) {
          ownerIsCurrent = false;
        }
        break;
      }
    }

    var shieldValue = MonsterBox.getShieldValue(owner, data);

    return ColorFiltered(
      //gray out if summoned this turn and it's still the character's/monster's turn
        colorFilter: (data.roundSummoned == getIt<GameState>().round.value &&
            ownerIsCurrent)
            ? ColorFilter.matrix(grayScale)
            : ColorFilter.matrix(identity),
        child: Container(
            padding: EdgeInsets.zero,
            height: 30 * scale,
            width: width,
            decoration: BoxDecoration(
              color: Color(int.parse("7A000000", radix: 16)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black45,
                  blurRadius: 4 * scale,
                  offset: Offset(2 * scale, 4 * scale), // Shadow position
                ),
              ],
            ),
            //color: Color(int.parse("7A000000", radix: 16)),
            //black with some opacity
            child: Stack(alignment: Alignment.centerLeft, children: [
              Image(
                height: 30 * scale,
                width: MonsterBox.getBoxBaseWidth(owner, data) * scale,
                fit: BoxFit.fill,
                color: borderColor,
                colorBlendMode: blendMode,
                // (works but not great),// BlendMode.modulate/color (good for boss), //BlendMode.saturation,(not good for boss)
                // scale up disregarding aspect ratio
                image: const AssetImage("assets/images/psd/monster-box.png"),
              ),
              Container(
                margin: EdgeInsets.only(
                    left: shieldValue > 0 ? 4 * scale : 3 * scale,
                    top: 3 * scale,
                    bottom: 2 * scale
                ),
                child: Image(
                  //fit: BoxFit.contain,
                  height: 100 * scale,
                  width: 17 * scale,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.medium,
                  image: AssetImage(imagePath),
                ),
              ),
              Positioned(
                width: 22 * scale,
                //baked in edge insets to line up with picture
                top: 1 * scale,
                left: shieldValue > 0 ? 1 * scale : 0 * scale,
                child: Text(
                  textAlign: TextAlign.center,
                  standeeNr,
                  style: TextStyle(
                      color: color, fontSize: 20 * scale, shadows: [shadow]
                  ),
                ),
              ),
              Positioned(
                left: data.health.value > 99 ? 22 * scale : 23.5 * scale,
                top: 2.5 * scale,
                child: Container(
                    padding: EdgeInsets.zero,
                    margin: EdgeInsets.zero,
                    child: Row(children: [
                      Column(children: [
                        Container(
                          margin: EdgeInsets.only(bottom: 0.5 * scale),
                          child: Image(
                            //fit: BoxFit.contain,
                            color: Colors.red,
                            height: 7 * scale,
                            image: const AssetImage("assets/images/blood.png"),
                          ),
                        ),
                        Container(
                          margin: EdgeInsets.only(bottom: 1 * scale),
                          width: data.health.value > 99
                              ? 21 * scale
                              : 16.8 * scale,
                          alignment: Alignment.center,
                          child: Text(
                            textAlign: TextAlign.end,
                            "${data.health.value}",
                            style: TextStyle(
                                height: 1,
                                color: Colors.white,
                                fontSize: 16 * scale,
                                shadows: [shadow]
                            ),
                          ),
                        ),
                      ]),
                      Column(children: [ if (shieldValue > 0) ...[
                        Container(
                          margin: EdgeInsets.only(bottom: 0.5 * scale),
                          child: Image(
                            //fit: BoxFit.contain,
                            color: Colors.white,
                            height: 7 * scale,
                            colorBlendMode: BlendMode.modulate,
                            image: const AssetImage(
                                "assets/images/abilities/shield_fh.png"),
                          ),
                        ),
                        Container(
                          margin: EdgeInsets.only(bottom: 1 * scale),
                          width: shieldValue > 99
                              ? 21 * scale
                              : 16.8 * scale,
                          alignment: Alignment.center,
                          child: Text(
                            textAlign: TextAlign.end,
                            "$shieldValue",
                            style: TextStyle(
                                height: 1,
                                color: Colors.white,
                                fontSize: 16 * scale,
                                shadows: [shadow]
                            ),
                          ),
                        ),
                      ]
                      ]),
                    ])),
              ),
              Positioned(
                  top: 0,
                  left: (MonsterBox.getBoxBaseWidth(owner, data) - 0.5) * scale,
                  child: ValueListenableBuilder<List<Condition>>(
                      valueListenable: data.conditions,
                      builder: (context, value, child) {
                        return SizedBox(
                            height: 30 * scale,
                            child: Wrap(
                              spacing: 0,
                              runSpacing: 0,
                              direction: Axis.vertical,
                              alignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: createConditionList(scale),
                            )
                        );
                      }
                  )),
              Container(
                //the hp bar
                  margin: EdgeInsets.only(
                    bottom: 2.5 * scale,
                    left: shieldValue > 0 ? 3.7 * scale : 2.7 * scale,
                  ),
                  alignment: Alignment.bottomCenter,
                  width: math.max(
                    0,
                    (MonsterBox.getBoxBaseWidth(owner, data) - (shieldValue > 0 ? 7.7 : 5.5)) * scale
                  ),
                  child: ValueListenableBuilder<int>(
                      valueListenable: data.maxHealth,
                      builder: (context, value, child) {
                        return FAProgressBar(
                          currentValue: data.health.value.toDouble(),
                          maxValue: data.maxHealth.value.toDouble(),
                          size: 4.0 * scale,
                          direction: Axis.horizontal,
                          borderRadius: BorderRadius.circular(0),
                          border: Border.all(
                            color: Colors.black,
                            width: 0.5 * scale,
                          ),
                          backgroundColor: Colors.black,
                          progressColor: Colors.red,
                          changeColorValue: (data.maxHealth.value).toInt(),
                          changeProgressColor: Colors.green,
                        );
                      }))
            ])));
  }

  @override
  Widget build(BuildContext context) {
    double scale = widget.scale;
    var figure = GameMethods.getFigure(widget.ownerId, widget.figureId);
    if (figure != null) {
      data = figure as MonsterInstance;
    }
    Color color = Colors.white;
    if (data.type == MonsterType.elite) {
      color = Colors.yellow;
    }
    if (data.type == MonsterType.boss) {
      color = Colors.red;
    }

    String figureId = data.getId();
    String? characterId;
    if (widget.ownerId != data.name) {
      characterId = widget.ownerId; //this is probably wrong
    }

    return GestureDetector(
      onTap: () {
        //open stats menu
        if (!widget.blockInput) {
          openDialog(
            context,
            ActionMenu(
                figureId: figureId,
                monsterId: getMonsterId(),
                characterId: characterId
            ),
          );
        }
      },
      child: ValueListenableBuilder<dynamic>(
        valueListenable: _gameState.characterShields,
        builder: (context, value, child) {
          double width = math.max(0, MonsterBox.getWidth(scale, owner, data));

          return HealthWheelController(
            figureId: widget.figureId,
            ownerId: widget.ownerId,
            child: AnimatedContainer(
              //makes it grow nicely when adding conditions
                key: Key(figureId.toString()),
                width: width,
                curve: Curves.easeInOut,
                duration: const Duration(milliseconds: 300),
                child:
                ValueListenableBuilder<int>(
                  valueListenable: data.health,
                  builder: (context, value, child) {
                    bool alive = true;
                    if (data.health.value <= 0) {
                      alive = false;
                    }

                    double offset = -30 * scale;
                    Widget child = buildInternal(scale, width, color);

                    if (widget.displayStartAnimation != widget.figureId) {
                      //if this one is not added - only play death animation
                      return TranslationAnimatedWidget.tween(
                          enabled: !alive && !widget.blockInput,
                          translationDisabled: const Offset(0, 0),
                          translationEnabled: Offset(
                              0, alive ? 0 : -offset),
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.linear,
                          child: child);
                    }

                    return TranslationAnimatedWidget.tween(
                        enabled: true,
                        //fix is to only set enabled on added/removed ones?
                        translationDisabled: Offset(
                            0, alive ? offset : 0),
                        translationEnabled: Offset(
                            0, alive ? 0 : -offset),
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.linear,
                        child: OpacityAnimatedWidget.tween(
                            enabled: alive,
                            opacityDisabled: 0,
                            opacityEnabled: 1,
                            child: child));
                  }
                )
            ),
          );
        }
      )
    );
  }
}
