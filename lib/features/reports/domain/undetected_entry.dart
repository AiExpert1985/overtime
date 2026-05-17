class UndetectedEntry {
  const UndetectedEntry({
    required this.name,
    required this.department,
    required this.failureReason,
    required this.timestamps,
  });

  final String name;
  final String department;
  final String failureReason;
  final List<DateTime> timestamps;
}
