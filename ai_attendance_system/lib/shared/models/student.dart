class Student {
  const Student({
    required this.id,
    required this.name,
    required this.email,
    required this.className,
    required this.semester,
    required this.batch,
    required this.group,
    required this.status,
    required this.attendanceRate,
  });

  final String id;
  final String name;
  final String email;
  final String className;
  final String semester;
  final String batch;
  final String group;
  final String status;
  final double attendanceRate;
}
