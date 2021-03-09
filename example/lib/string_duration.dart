extension FormatString on Duration {
  String get mmSSFormat {
    String twoDigits(int n) {
      if (n >= 10) return '$n';
      return '0$n';
    }

    String twoDigitMinutes =
        twoDigits(this.inMinutes.remainder(Duration.minutesPerHour));
    String twoDigitSeconds =
        twoDigits(this.inSeconds.remainder(Duration.secondsPerMinute));
    return '$twoDigitMinutes:$twoDigitSeconds';
  }
}
