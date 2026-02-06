class ReportSummary {
  const ReportSummary({
    required this.attendanceRate,
    required this.absentRate,
    required this.totalStudents,
    required this.reportsGenerated,
  });

  final double attendanceRate;
  final double absentRate;
  final int totalStudents;
  final int reportsGenerated;
}
