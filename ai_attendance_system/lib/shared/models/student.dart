class Student {
  const Student({
    required this.id,
    required this.name,
    required this.email,
    required this.className,
    required this.status,
    required this.attendanceRate,
  });

  final String id;
  final String name;
  final String email;
  final String className;
  final String status;
  final double attendanceRate;
}
