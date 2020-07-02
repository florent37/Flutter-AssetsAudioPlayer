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
