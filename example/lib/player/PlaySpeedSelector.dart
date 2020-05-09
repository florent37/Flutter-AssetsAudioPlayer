import 'package:assets_audio_player/assets_audio_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter_neumorphic/flutter_neumorphic.dart';

class PlaySpeedSelector extends StatelessWidget {
  final double playSpeed;
  final Function(double) onChange;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Wrap(
        children: <Widget>[
          Text(
            "PlaySpeed ",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Row(
            children: [
              _button(-4.0),
              _button(-2.0),
              _button(1.0),
              _button(2.0),
              _button(4.0),
            ],
          ),
          SizedBox(
              width: 40,
              child: Text(
                "${(playSpeed * 100).floor() / 100}",
              ))
        ],
      ),
    );
  }

  Widget _button(double value){
    return NeumorphicButton(
      margin: EdgeInsets.all(4),
      boxShape: NeumorphicBoxShape.circle(),
      child: Text(
          "x$value"
      ),
      onClick: (){
        this.onChange(value);
      },
    );
  }

  const PlaySpeedSelector({
    @required this.playSpeed,
    @required this.onChange,
  });
}
