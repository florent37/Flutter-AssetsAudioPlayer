import 'package:flutter/material.dart';
import 'package:flutter_neumorphic/flutter_neumorphic.dart';

class PositionSeekWidget extends StatelessWidget {
  final Duration currentPosition;
  final Duration duration;
  final Function(Duration) seekTo;

  const PositionSeekWidget({
    @required this.currentPosition,
    @required this.duration,
    @required this.seekTo,
  });

  double get percent => duration.inMilliseconds == 0 ? 0 : currentPosition.inMilliseconds / duration.inMilliseconds;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          SizedBox(
            width: 40,
            child: Text(durationToString(currentPosition)),
          ),
          Expanded(
            child: NeumorphicSlider(
              min: 0,
              max: duration.inMilliseconds.toDouble(),
              value: percent * duration.inMilliseconds.toDouble(),
              style: SliderStyle(
                  variant: Colors.grey,
                  accent: Colors.grey[500]
              ),
              onChanged: (newValue) {
                final to = Duration(milliseconds: newValue.floor());
                //print("to $to");
                seekTo(to);
              },
            ),
          ),
          SizedBox(
            width: 40,
            child: Text(durationToString(duration)),
          ),
        ],
      ),
    );
  }
}

String durationToString(Duration duration) {
  String twoDigits(int n) {
    if (n >= 10) return "$n";
    return "0$n";
  }

  String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(Duration.minutesPerHour));
  String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(Duration.secondsPerMinute));
  return "$twoDigitMinutes:$twoDigitSeconds";
}
