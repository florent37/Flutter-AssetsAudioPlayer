enum HeadPhoneStrategy { none, pauseOnUnplug, pauseOnUnplugPlayOnPlug }

String describeHeadPhoneStrategy(HeadPhoneStrategy strategy) {
  switch (strategy) {
    case HeadPhoneStrategy.none:
      return "none";
    case HeadPhoneStrategy.pauseOnUnplug:
      return "pauseOnUnplug";
    case HeadPhoneStrategy.pauseOnUnplugPlayOnPlug:
      return "pauseOnUnplugPlayOnPlug";
  }
}

enum PhoneCallStrategy { none, pauseOnPhoneCall, pauseOnPhoneCallResumeAfter }

String describePhoneCallStrategy(PhoneCallStrategy strategy) {
  switch (strategy) {
    case PhoneCallStrategy.none:
      return "none";
    case PhoneCallStrategy.pauseOnPhoneCall:
      return "pauseOnPhoneCall";
    case PhoneCallStrategy.pauseOnPhoneCallResumeAfter:
      return "pauseOnPhoneCallResumeAfter";
  }
}
