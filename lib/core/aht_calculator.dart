class AhtCalculator {
  static int totalSeconds(Iterable<int> durations) =>
      durations.fold(0, (sum, seconds) => sum + seconds);

  static double average(Iterable<int> durations) {
    final values = durations.toList();
    if (values.isEmpty) return 0;
    return totalSeconds(values) / values.length;
  }

  static double? requiredFutureAverage({
    required int currentCalls,
    required int totalSeconds,
    required int targetSeconds,
    required int remainingCalls,
  }) {
    if (remainingCalls <= 0) return null;
    return (targetSeconds * (currentCalls + remainingCalls) - totalSeconds) /
        remainingCalls;
  }
}
