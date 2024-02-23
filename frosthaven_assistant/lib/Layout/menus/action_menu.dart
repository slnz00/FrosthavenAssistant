import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:frosthaven_assistant/Layout/menus/status_menu.dart';
import '../../Resource/commands/add_condition_command.dart';
import '../../Resource/commands/remove_condition_command.dart';
import '../../Resource/effect_handler.dart';
import '../../Resource/enums.dart';
import '../../Resource/state/game_state.dart';
import '../../Resource/ui_utils.dart';
import '../../services/service_locator.dart';

class ActionStats {
  final ValueNotifier<int> pierceAmount = ValueNotifier(0);

  final bool attack;

  ActionStats({required this.attack});
}

class ActionData {
  final GameState _gameState = getIt<GameState>();

  late final ActionStats stats;

  final ValueNotifier<List<Condition>> conditions = ValueNotifier([]);
  final ValueNotifier<int> healthChange = ValueNotifier(0);

  bool get attack => stats.attack;

  final String figureId;
  final String? monsterId;
  final String? characterId;
  late final String ownerId;

  ActionData({ required this.figureId, this.monsterId, this.characterId, required bool attack }) {
    var localOwnerId = "";

    if (monsterId != null) {
      localOwnerId = monsterId!;
    } else if (characterId != null) {
      localOwnerId = characterId!;
    }

    ownerId = localOwnerId;
    conditions.value = _getConditionsFromGameState();
    stats = ActionStats(attack: attack);
  }

  void process () {
    var conditionsBeforeHealthChange = _getConditionsFromGameState();
    _handleHealthChange();
    _handleConditionChanges(conditionsBeforeHealthChange);
  }

  void _saveConditionToGameState(Condition condition, bool activate) {
    if (activate) {
      _gameState.action(AddConditionCommand(condition, figureId, ownerId));
    } else {
      _gameState.action(RemoveConditionCommand(condition, figureId, ownerId));
    }
  }

  void _handleConditionChanges(List<Condition> currentConditions) {
    var newConditions = conditions.value;

    for (var condition in newConditions) {
      if (!currentConditions.contains(condition)) {
        _saveConditionToGameState(condition, true);
      }
    }

    for (var condition in currentConditions) {
      if (!newConditions.contains(condition)) {
        _saveConditionToGameState(condition, false);
      }
    }
  }

  void _handleHealthChange() {
    var changeValue = healthChange.value;

    if (attack && changeValue > 0) {
      changeValue *= -1;
    }

    EffectHandler.handleHealthChange(FigureData(ownerId, figureId), changeValue, stats);

    healthChange.value = 0;
  }

  List<Condition> _getConditionsFromGameState() {
    var figure = GameMethods.getFigure(ownerId, figureId);

    if (figure is MonsterInstance) {
      return [...figure.conditions.value];
    }
    if (figure is CharacterState) {
      return [...figure.conditions.value];
    }

    return [];
  }
}

class ActionMenu extends StatefulWidget {
  const ActionMenu(
      {Key? key, required this.figureId, this.characterId, this.monsterId})
      : super(key: key);

  final String figureId;
  final String? monsterId;
  final String? characterId;

  @override
  ActionMenuState createState() => ActionMenuState();
}

class ActionMenuState extends State<ActionMenu> {
  @override
  initState() {
    // at the beginning, all items are shown
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    double scale = 1;
    if (!isPhoneScreen(context)) {
      scale = 1.5;
      if (isLargeTablet(context)) {
        scale = 2;
      }
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      mainAxisSize: MainAxisSize.min,
      children: [
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.zero,
            foregroundColor: Colors.black,
            disabledBackgroundColor: Colors.blueGrey,
            fixedSize: Size(120 * scale, 50 * scale),
            backgroundColor: Colors.white,
            elevation: 4,
          ),
          onPressed: () {
            Navigator.of(context, rootNavigator: true).pop();

            var actionData = ActionData(
              attack: true,
              figureId: widget.figureId,
              monsterId: widget.monsterId,
              characterId: widget.characterId,
            );

            openDialog(
              context,
              StatusMenu(actionData: actionData)
            ).then((val) {
              actionData.process();
            });
          },
          child: Text(
            "Attack",
            style: getTitleTextStyle(scale),
            maxLines: 1,
          ),
        ),
        SizedBox(
          width: 50 * scale,
          height: 50 * scale,
        ),
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.zero,
            foregroundColor: Colors.black,
            disabledBackgroundColor: Colors.blueGrey,
            fixedSize: Size(120 * scale, 50 * scale),
            backgroundColor: Colors.white,
            elevation: 4,
          ),
          onPressed: () {
            Navigator.of(context, rootNavigator: true).pop();

            var actionData = ActionData(
              attack: false,
              figureId: widget.figureId,
              monsterId: widget.monsterId,
              characterId: widget.characterId,
            );

            openDialog(
              context,
              StatusMenu(actionData: actionData)
            ).then((val) {
              actionData.process();
            });
          },
          child: Text(
            "Passive",
            style: getTitleTextStyle(scale),
            maxLines: 1,
          ),
        )
      ],
    );
  }
}
