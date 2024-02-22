import 'package:flutter/material.dart';
import 'package:frosthaven_assistant/Layout/main_list.dart';

import '../Resource/commands/draw_command.dart';
import '../Resource/commands/next_round_command.dart';
import '../Resource/enums.dart';
import '../Resource/global_keys.dart';
import '../Resource/state/game_state.dart';
import '../Resource/settings.dart';
import '../Resource/ui_utils.dart';
import '../services/service_locator.dart';

class DrawButton extends StatefulWidget {
  const DrawButton({
    Key? key,
  }) : super(key: key);

  @override
   DrawButtonState createState() => DrawButtonState();
}

class DrawButtonState extends State<DrawButton> {
  final GameState _gameState = getIt<GameState>();

  @override
  void initState() {
    super.initState();
  }

  void onPressed() {
    if (_gameState.roundState.value == RoundState.chooseInitiative) {
      if (GameMethods.canDraw()) {
        _gameState.action(DrawCommand());
        return;
      }

      if (_gameState.currentList.isEmpty) {
        showToast(context, "Add characters first.");
        return;
      }

      showToast(
        context,
        "Player Initiative numbers must be set (under the initiative marker to the right of the character symbol)"
      );

      var mainListState = GlobalKeys.mainList.currentState;
      if (mainListState is MainListState) {
        mainListState.focusNextEmptyInitInput();
      }
    } else {
      _gameState.action(NextRoundCommand());
    }
  }

  @override
  Widget build(BuildContext context) {
    //TextButton says Draw/Next Round
    //has a turn counter
    //and a timer
    //2 states
    Settings settings = getIt<Settings>();
    return ValueListenableBuilder<double>(
        valueListenable: settings.userScalingBars,
        builder: (context, value, child) {
          var shadow = Shadow(
            offset: Offset(1 * settings.userScalingBars.value,
                1 * settings.userScalingBars.value),
            color: Colors.black87,
            blurRadius: 1 * settings.userScalingBars.value,
          );

          return Stack(alignment: Alignment.centerLeft, children: [
            ValueListenableBuilder<RoundState>(
              valueListenable: _gameState.roundState,
              builder: (context, value, child) {
                return Container(
                    margin: EdgeInsets.zero,
                    height: 40 * settings.userScalingBars.value,
                    width: 60 * settings.userScalingBars.value,
                    child: TextButton(
                        style: TextButton.styleFrom(
                            padding: EdgeInsets.only(
                                left: 10 * settings.userScalingBars.value,
                                right: 10 * settings.userScalingBars.value),
                            //minimumSize: Size(50, 30),
                            //tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            alignment: Alignment.center),
                        onPressed: onPressed,
                        child: Text(
                          _gameState.roundState.value ==
                                  RoundState.chooseInitiative
                              ? "Draw"
                              : " Next Round",
                          style: TextStyle(
                            height: 0.8,
                            fontSize: 16 * settings.userScalingBars.value,
                            color: Colors.white,
                            shadows: [shadow],
                          ),
                        )));
              },
            ),
            ValueListenableBuilder<int>(
              valueListenable: _gameState.round,
              builder: (context, value, child) {
                return Positioned(
                    bottom: 2 * settings.userScalingBars.value,
                    right: 3.5 * settings.userScalingBars.value,
                    // width: 60,
                    child: Text(_gameState.round.value.toString(),
                        style: TextStyle(
                          fontSize: 14 * settings.userScalingBars.value,
                          color: Colors.white,
                          shadows: [shadow],
                        )));
              },
            )
          ]);
        });
  }
}
