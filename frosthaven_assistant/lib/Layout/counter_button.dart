import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../Resource/commands/change_stat_commands/change_stat_command.dart';
import '../Resource/state/game_state.dart';
import '../services/service_locator.dart';

class CounterButton extends StatefulWidget {
  final ValueListenable<int> notifier;
  final ChangeStatCommand? command;
  final bool Function(int)? callback;
  final int maxValue;
  final String image;
  final String figureId;
  final String ownerId;
  final bool showTotalValue;
  final Color color;
  final double scale;

  const CounterButton(this.notifier, this.command, this.maxValue, this.image,
      this.showTotalValue, this.color,
      {Key? key,
      this.callback,
      required this.figureId,
      required this.ownerId,
      required this.scale})
      : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return CounterButtonState();
  }
}

class CounterButtonState extends State<CounterButton> {
  GameState gameState = getIt<GameState>();
  final totalChangeValue = ValueNotifier<int>(0);

  @override
  Widget build(BuildContext context) {
    FigureState? figure =
        GameMethods.getFigure(widget.ownerId, widget.figureId);
    if (figure == null && widget.figureId != "unknown") {
      //in case it dies and was removed from the list
      return Container();
    }
    return Row(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(
          width: 40 * widget.scale,
          height: 40 * widget.scale,
          child: IconButton(
              icon: Image.asset('assets/images/psd/sub.png'),
//iconSize: 30,
              onPressed: () {
                if (widget.command != null) {
                  widget.command!.setChange(-1);
                }
                if (widget.callback != null) {
                  if (widget.callback!(-1)) {
                    totalChangeValue.value--;
                  }

                  return;
                }

                if (widget.notifier.value > 0) {
                  totalChangeValue.value--;

                  if (widget.command != null) {
                    gameState.action(widget.command!);
                  }

                  if (widget.figureId != "unknown" &&
                      widget.notifier == figure!.health &&
                      figure.health.value <= 0) {
                    {
                      Navigator.pop(context);
                    }
                  }
                }
              })),
      Stack(children: [
        SizedBox(
          width: 30 * widget.scale,
          height: 30 * widget.scale,
          child: Image(
            color: widget.color,
            colorBlendMode: BlendMode.modulate,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
            image: AssetImage(widget.image),
          ),
        ),
        ValueListenableBuilder<int>(
            valueListenable: widget.showTotalValue ? widget.notifier : totalChangeValue,
            builder: (context, value, child) {
              String text = "";
              if (totalChangeValue.value > 0) {
                text = "+${totalChangeValue.value.toString()}";
              } else if (totalChangeValue.value != 0) {
                text = totalChangeValue.value.toString();
              }
              if (widget.showTotalValue) {
                text = widget.notifier.value.toString();
              }
              var shadow = Shadow(
                offset: Offset(1 * widget.scale, 1 * widget.scale),
                color: Colors.black,
                blurRadius: 1 * widget.scale,
              );
              return Positioned(
                  bottom: 0,
                  right: 0,
                  child: Text(
                    text,
                    style: TextStyle(
                        height: 0.5,
                        fontSize: 16 * widget.scale,
                        color: Colors.white, //widget.color,
                        shadows: [shadow]),
                  ));
            })
      ]),
      SizedBox(
          width: 40 * widget.scale,
          height: 40 * widget.scale,
          child: IconButton(
            icon: Image.asset('assets/images/psd/add.png'),
//iconSize: 30,
            onPressed: () {
              if (widget.command != null) {
                widget.command!.setChange(1);
              }
              if (widget.callback != null) {
                if (widget.callback!(1)) {
                  totalChangeValue.value++;
                }

                return;
              }

              if (widget.notifier.value < widget.maxValue) {

                if (widget.command != null) {
                  gameState.action(widget.command!);
                }

                totalChangeValue.value++;

                if (widget.figureId != "unknown" &&
                    widget.notifier.value <= 0 &&
                    widget.notifier == figure!.health) {
                  Navigator.pop(context);
                }
              }
//increment
            },
          )),
    ]);
  }
}
