class SessionHistory {
  const SessionHistory({
    required this.id,
    required this.label,
    required this.title,
    required this.className,
    required this.department,
    required this.semester,
    required this.batch,
    required this.group,
    required this.marked,
    required this.total,
  });

  final String id;
  final String label;
  final String title;
  final String className;
  final String department;
  final String semester;
  final String batch;
  final String group;
  final int marked;
  final int total;

  double get percentage => total == 0 ? 0 : (marked / total) * 100;
}
