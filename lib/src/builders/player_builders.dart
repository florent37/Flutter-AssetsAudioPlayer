import 'package:assets_audio_player/assets_audio_player.dart';
import 'package:flutter/widgets.dart';

enum _PlayingBuilderType {
  isPlaying,
  volume,
  currentPosition,
  playSpeed,
  forwardRewindSpeed,
  current,
  loopMode,
  isBuffering,
  realtimePlayingInfos,
  playerState,
}

typedef PlayingWidgetBuilder = Widget Function(
    BuildContext context, bool isPlaying);
typedef LoopModeWidgetBuilder = Widget Function(
    BuildContext context, LoopMode loopMode);
typedef VolumeWidgetBuilder = Widget Function(
    BuildContext context, double volume);
typedef PlaySpeedWidgetBuilder = Widget Function(
    BuildContext context, double playSpeed);
typedef ForwardRewindSpeedWidgetBuilder = Widget Function(
    BuildContext context, double playSpeed);
typedef PositionWidgetBuilder = Widget Function(
    BuildContext context, Duration position);
typedef CurrentWidgetBuilder = Widget Function(
    BuildContext context, Playing playing);
typedef IsBufferingWidgetBuilder = Widget Function(
    BuildContext context, bool isBuffering);
typedef RealtimeWidgetBuilder = Widget Function(
    BuildContext context, RealtimePlayingInfos realtimePlayingInfos);
typedef PlayerStateBuilder = Widget Function(
    BuildContext context, PlayerState playerState);

class PlayerBuilder extends StatefulWidget {
  final AssetsAudioPlayer player;
  final dynamic builder;
  final _PlayingBuilderType builderType;

  const PlayerBuilder.isPlaying(
      {Key key, @required this.player, @required PlayingWidgetBuilder builder})
      : this.builder = builder,
        this.builderType = _PlayingBuilderType.isPlaying,
        super(key: key);

  const PlayerBuilder.isBuffering(
      {Key key, @required this.player, @required PlayingWidgetBuilder builder})
      : this.builder = builder,
        this.builderType = _PlayingBuilderType.isBuffering,
        super(key: key);

  const PlayerBuilder.loopMode(
      {Key key, @required this.player, @required LoopModeWidgetBuilder builder})
      : this.builder = builder,
        this.builderType = _PlayingBuilderType.loopMode,
        super(key: key);

  const PlayerBuilder.realtimePlayingInfos(
      {Key key, @required this.player, @required RealtimeWidgetBuilder builder})
      : this.builder = builder,
        this.builderType = _PlayingBuilderType.realtimePlayingInfos,
        super(key: key);

  const PlayerBuilder.volume(
      {Key key, @required this.player, @required VolumeWidgetBuilder builder})
      : this.builder = builder,
        this.builderType = _PlayingBuilderType.volume,
        super(key: key);

  const PlayerBuilder.playSpeed(
      {Key key,
      @required this.player,
      @required PlaySpeedWidgetBuilder builder})
      : this.builder = builder,
        this.builderType = _PlayingBuilderType.playSpeed,
        super(key: key);

  const PlayerBuilder.currentPosition(
      {Key key, @required this.player, @required PositionWidgetBuilder builder})
      : this.builder = builder,
        this.builderType = _PlayingBuilderType.currentPosition,
        super(key: key);

  const PlayerBuilder.forwardRewindSpeed(
      {Key key, @required this.player, ForwardRewindSpeedWidgetBuilder builder})
      : this.builder = builder,
        this.builderType = _PlayingBuilderType.forwardRewindSpeed,
        super(key: key);

  const PlayerBuilder.current(
      {Key key, @required this.player, @required CurrentWidgetBuilder builder})
      : this.builder = builder,
        this.builderType = _PlayingBuilderType.current,
        super(key: key);

  const PlayerBuilder.playerState(
      {Key key, @required this.player, @required PlayerStateBuilder builder})
      : this.builder = builder,
        this.builderType = _PlayingBuilderType.playerState,
        super(key: key);

  @override
  _PlayerBuilderState createState() => _PlayerBuilderState();
}

class _PlayerBuilderState extends State<PlayerBuilder> {
  @override
  Widget build(BuildContext context) {
    switch (widget.builderType) {
      case _PlayingBuilderType.isPlaying:
        return StreamBuilder(
          stream: widget.player.isPlaying,
          initialData: false,
          builder: (context, snap) {
            return this.widget.builder(context, snap.data);
          },
        );
        break;
      case _PlayingBuilderType.isBuffering:
        return StreamBuilder(
          stream: widget.player.isBuffering,
          initialData: false,
          builder: (context, snap) {
            return this.widget.builder(context, snap.data);
          },
        );
        break;
      case _PlayingBuilderType.loopMode:
        return StreamBuilder(
          stream: widget.player.loopMode,
          initialData: LoopMode.none,
          builder: (context, snap) {
            return this.widget.builder(context, snap.data);
          },
        );
        break;
      case _PlayingBuilderType.volume:
        return StreamBuilder(
          stream: widget.player.volume,
          initialData: AssetsAudioPlayer.defaultVolume,
          builder: (context, snap) {
            return this.widget.builder(context, snap.data);
          },
        );
        break;
      case _PlayingBuilderType.currentPosition:
        return StreamBuilder(
          stream: widget.player.currentPosition,
          initialData: Duration.zero,
          builder: (context, snap) {
            return this.widget.builder(context, snap.data);
          },
        );
        break;
      case _PlayingBuilderType.playSpeed:
        return StreamBuilder(
          stream: widget.player.playSpeed,
          initialData: AssetsAudioPlayer.defaultPlaySpeed,
          builder: (context, snap) {
            return this.widget.builder(context, snap.data);
          },
        );
        break;
      case _PlayingBuilderType.forwardRewindSpeed:
        return StreamBuilder(
          stream: widget.player.forwardRewindSpeed,
          initialData: null,
          builder: (context, snap) {
            return this.widget.builder(context, snap.data);
          },
        );
        break;
      case _PlayingBuilderType.current:
        return StreamBuilder(
          stream: widget.player.current,
          initialData: null,
          builder: (context, snap) {
            return this.widget.builder(context, snap.data);
          },
        );
        break;
      case _PlayingBuilderType.realtimePlayingInfos:
        return StreamBuilder(
          stream: widget.player.realtimePlayingInfos,
          initialData: null,
          builder: (context, snap) {
            return this.widget.builder(context, snap.data);
          },
        );
        break;
      case _PlayingBuilderType.playerState:
        return StreamBuilder(
          stream: widget.player.playerState,
          initialData: PlayerState.stop,
          builder: (context, snap) {
            return this.widget.builder(context, snap.data);
          },
        );
        break;
    }
    return SizedBox();
  }
}

class PlayerGroupBuilder extends StatefulWidget {
  final AssetsAudioPlayerGroup player;
  final dynamic builder;
  final _PlayingBuilderType builderType;

  const PlayerGroupBuilder.isPlaying(
      {Key key, @required this.player, @required PlayingWidgetBuilder builder})
      : this.builder = builder,
        this.builderType = _PlayingBuilderType.isPlaying,
        super(key: key);

  @override
  createState() => _PlayerBuilderGroupState();
}

class _PlayerBuilderGroupState extends State<PlayerGroupBuilder> {
  @override
  Widget build(BuildContext context) {
    switch (widget.builderType) {
      case _PlayingBuilderType.isPlaying:
        return StreamBuilder(
          stream: widget.player.isPlaying,
          initialData: false,
          builder: (context, snap) {
            return this.widget.builder(context, snap.data);
          },
        );
        break;
      default: /* do nothing */
    }
    return SizedBox();
  }
}
