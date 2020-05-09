import 'package:assets_audio_player/assets_audio_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter_neumorphic/flutter_neumorphic.dart';

class ForwardRewindSelector extends StatelessWidget {
  final double speed;
  final Function(double) onChange;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          Text(
            "Forward/Rewind ",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          _button(-2),
          _button(2.0),
        ],
      ),
    );
  }

  Widget _button(double value){
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: NeumorphicRadio(
        groupValue: this.speed,
        padding: EdgeInsets.all(12.0),
        value: value,
        boxShape: NeumorphicBoxShape.circle(),
        child: Text(
            "x$value"
        ),
        onChanged: (v){
          this.onChange(v);
        },
      ),
    );
  }

  const ForwardRewindSelector({
    @required this.speed,
    @required this.onChange,
  });
}
