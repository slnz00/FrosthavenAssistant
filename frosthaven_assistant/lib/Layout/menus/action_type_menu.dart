import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:frosthaven_assistant/Layout/menus/status_menu.dart';
import '../../Resource/state/game_state.dart';
import '../../Resource/ui_utils.dart';
import '../../services/service_locator.dart';

class ActionTypeMenu extends StatefulWidget {
  const ActionTypeMenu(
      {Key? key, required this.figureId, this.characterId, this.monsterId})
      : super(key: key);

  final String figureId;
  final String? monsterId;
  final String? characterId;

  @override
  ActionTypeMenuState createState() => ActionTypeMenuState();
}

class ActionTypeMenuState extends State<ActionTypeMenu> {
  final GameState _gameState = getIt<GameState>();

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
            openDialog(
              context,
              StatusMenu(
                  attack: true,
                  figureId: widget.figureId,
                  monsterId: widget.monsterId,
                  characterId: widget.characterId
              )
            );
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
            openDialog(
              context,
              StatusMenu(
                  attack: false,
                  figureId: widget.figureId,
                  monsterId: widget.monsterId,
                  characterId: widget.characterId
              )
            );
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
