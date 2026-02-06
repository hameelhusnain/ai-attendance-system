class AttendanceRecord {
  const AttendanceRecord({
    required this.id,
    required this.studentName,
    required this.date,
    required this.status,
    required this.className,
  });

  final String id;
  final String studentName;
  final String date;
  final String status;
  final String className;
}
