import 'package:flutter/widgets.dart';
import 'package:assets_audio_player/assets_audio_player.dart';

///for now its in the sample, but will be part of the project

typedef PlayingWidgetBuilder = Widget Function(BuildContext context, bool isPlaying);
class PlayingBuilder extends StatelessWidget {
  final AssetsAudioPlayer player;
  final PlayingWidgetBuilder builder;

  const PlayingBuilder({Key key, this.player, this.builder}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: player.isPlaying,
      initialData: false,
      builder: (context, snap) {
        final bool isPlaying = snap.data;
        return this.builder(context, isPlaying);
      },
    );
  }
}
