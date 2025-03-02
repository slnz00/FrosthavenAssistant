import 'package:flutter/material.dart';

import '../../Resource/game_data.dart';
import '../../Resource/settings.dart';
import '../../Resource/state/game_state.dart';
import '../../services/service_locator.dart';

class TreasureIndexMenu extends StatefulWidget {
  const TreasureIndexMenu({Key? key}) : super(key: key);

  @override
  TreasureIndexMenuState createState() => TreasureIndexMenuState();
}

class TreasureIndexMenuState extends State<TreasureIndexMenu> {
  late String _currentCampaign;
  late Map<String, String> _treasures;

  final _indexInputController = TextEditingController();
  final GameState _gameState = getIt<GameState>();
  final GameData _gameData = getIt<GameData>();
  final ValueNotifier<String> _treasureText = ValueNotifier('');

  @override
  initState() {
    _currentCampaign = _gameState.currentCampaign.value;

    _setCampaign(_currentCampaign);

    super.initState();
  }

  int compareEditions(String a, String b) {
    for (String item in _gameData.editions) {
      if (b == item && a != item) {
        return 1;
      }
      if (a == item && b != item) {
        return -1;
      }
    }
    return a.compareTo(b);
  }

  void _setCampaign(String campaign) {
    var campaignData = _gameData.modelData.value[campaign];

    _currentCampaign = campaign;
    _treasures = campaignData?.treasures ?? {};
    _indexInputController.clear();

    _setTreasureText('');
  }

  void _setTreasureText(String index) {
    if (_treasures.isEmpty) {
      _treasureText.value = 'Campaign does not have any treasures.';
      return;
    }

    if (index == '') {
      _treasureText.value = '';
      return;
    }

    _treasureText.value = _treasures[index] ?? 'Campaign does not have a treasure for the provided index.';
  }

  List<DropdownMenuItem<String>> buildEditionDropDownMenuItems() {
    List<DropdownMenuItem<String>> retVal = [];

    for (String item in _gameData.editions) {
      if (item != "na") {
        if (!GameMethods.isCustomCampaign(item) ||
            getIt<Settings>().showCustomContent.value == true) {
          retVal.add(DropdownMenuItem<String>(value: item, child: Text(item)));
        }
      }
    }

    return retVal;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        constraints: const BoxConstraints(maxWidth: 450, maxHeight: 260),
        child: Card(
          //color: Colors.transparent,
          // shadowColor: Colors.transparent,
            margin: const EdgeInsets.all(2),
            child: Stack(children: [
              Column(
                children: [
                  Row(children: [
                    const Text("      Show treasures from:   "),
                    DropdownButtonHideUnderline(
                        child: DropdownButton(
                            value: _currentCampaign,
                            items: buildEditionDropDownMenuItems(),
                            onChanged: (value) {
                              if (value is String) {
                                setState(() {
                                  _setCampaign(value);
                                });
                              }
                            }))
                  ]),
                  const SizedBox(
                    height: 5,
                  ),
                  Container(
                    margin: const EdgeInsets.only(left: 16, right: 16),
                    child: TextField(
                      controller: _indexInputController,
                      keyboardType: TextInputType.number,
                      onSubmitted: (value) {
                        _setTreasureText(value);
                      },
                      onTapOutside: (event) {
                        FocusScopeNode currentFocus = FocusScope.of(context);

                        if (!currentFocus.hasPrimaryFocus) {
                          currentFocus.unfocus();
                        }

                        _setTreasureText(_indexInputController.value.text);
                      },
                      decoration: const InputDecoration(
                        labelText: 'Index',
                        suffixIcon: Icon(Icons.info_outline)
                      ),
                    ),
                  ),
                  const SizedBox(
                    height: 40,
                  ),
                  ValueListenableBuilder<String>(
                    valueListenable: _treasureText,
                    builder: (context, value, child) {
                      return Container(
                        margin: const EdgeInsets.only(left: 16, right: 16),
                        child: Text(
                          value,
                          style: const TextStyle(fontSize: 16)
                        )
                      );
                    }
                  )
                ],
              ),
              Positioned(
                  width: 100,
                  height: 40,
                  right: -14,
                  bottom: 5,
                  child: TextButton(
                      child: const Text(
                        'Close',
                        style: TextStyle(fontSize: 20),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                      }))
            ])));
  }
}
