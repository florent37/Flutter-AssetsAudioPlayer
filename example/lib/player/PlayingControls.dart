import 'package:flutter/material.dart';
import 'package:flutter_neumorphic/flutter_neumorphic.dart';
import 'package:assets_audio_player/assets_audio_player.dart';

import '../asset_audio_player_icons.dart';

class PlayingControls extends StatelessWidget {
  final bool isPlaying;
  final LoopMode loopMode;
  final bool isPlaylist;
  final Function() onPrevious;
  final Function() onPlay;
  final Function() onNext;
  final Function() toggleLoop;

  PlayingControls({
    @required this.isPlaying,
    this.isPlaylist = false,
    this.loopMode,
    this.toggleLoop,
    this.onPrevious,
    @required this.onPlay,
    this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.max,
      children: [
        NeumorphicRadio(
          style: NeumorphicRadioStyle(
            boxShape: NeumorphicBoxShape.circle(),
          ),
          padding: EdgeInsets.all(12),
          value: LoopMode.playlist,
          groupValue: this.loopMode,
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
          style: NeumorphicStyle(
            boxShape: NeumorphicBoxShape.circle(),
          ),
          padding: EdgeInsets.all(18),
          onPressed: isPlaylist ? this.onPrevious : null,
          child: Icon(AssetAudioPlayerIcons.to_start),
        ),
        SizedBox(
          width: 12,
        ),
        NeumorphicButton(
          style: NeumorphicStyle(
            boxShape: NeumorphicBoxShape.circle(),
          ),
          padding: EdgeInsets.all(24),
          onPressed: this.onPlay,
          child: Icon(
            isPlaying
                ? AssetAudioPlayerIcons.pause
                : AssetAudioPlayerIcons.play,
            size: 32,
          ),
        ),
        SizedBox(
          width: 12,
        ),
        NeumorphicButton(
          style: NeumorphicStyle(
            boxShape: NeumorphicBoxShape.circle(),
          ),
          padding: EdgeInsets.all(18),
          child: Icon(AssetAudioPlayerIcons.to_end),
          onPressed: isPlaylist ? this.onNext : null,
        ),
        SizedBox(
          width: 45,
        )
      ],
    );
  }
}
