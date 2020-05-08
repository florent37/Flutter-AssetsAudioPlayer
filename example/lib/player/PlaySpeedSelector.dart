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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            "PlaySpeed ",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: NeumorphicSlider(
              min: AssetsAudioPlayer.minPlaySpeed,
              max: 2,
              //AssetsAudioPlayer.maxPlaySpeed,
              value: playSpeed,
              style: SliderStyle(variant: Colors.grey, accent: Colors.grey[500]),
              onChanged: (value) {
                this.onChange(value);
              },
            ),
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

  const PlaySpeedSelector({
    @required this.playSpeed,
    @required this.onChange,
  });
}
