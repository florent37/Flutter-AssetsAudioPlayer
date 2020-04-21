import 'package:flutter/material.dart';
import 'package:flutter_neumorphic/flutter_neumorphic.dart';

import '../asset_audio_player_icons.dart';

class PlayingControlsSmall extends StatelessWidget {
  final bool isPlaying;
  final bool isLooping;
  final Function() onPlay;
  final Function() toggleLoop;

  PlayingControlsSmall({
    @required this.isPlaying,
    @required this.isLooping,
    this.toggleLoop,
    @required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.max,
      children: [
        NeumorphicRadio(
          boxShape: NeumorphicBoxShape.circle(),
          padding: EdgeInsets.all(12),
          value: true,
          groupValue: this.isLooping,
          child: Icon(
            Icons.loop,
            size: 18,
          ),
          onChanged: (newValue) {
            toggleLoop();
          },
        ),
        SizedBox(
          width: 12,
        ),
        NeumorphicButton(
          boxShape: NeumorphicBoxShape.circle(),
          padding: EdgeInsets.all(16),
          onClick: this.onPlay,
          child: Icon(
            isPlaying
                ? AssetAudioPlayerIcons.pause
                : AssetAudioPlayerIcons.play,
            size: 32,
          ),
        ),
      ],
    );
  }
}
