import '../models/activity_item.dart';
import '../models/attendance_record.dart';
import '../models/report_item.dart';
import '../models/report_summary.dart';
import '../models/session_history.dart';
import '../models/student.dart';

class MockDataService {
  static const reportSummary = ReportSummary(
    attendanceRate: 86.4,
    absentRate: 13.6,
    totalStudents: 1240,
    reportsGenerated: 28,
  );

  static final List<Student> students = [
    const Student(
      id: 'S-1001',
      name: 'Ayaan Khan',
      email: 'ayaan.khan@campus.edu',
      className: 'CS-301',
      semester: 'Spring',
      batch: '2024',
      group: 'A',
      status: 'Active',
      attendanceRate: 92.5,
    ),
    const Student(
      id: 'S-1002',
      name: 'Fatima Noor',
      email: 'fatima.noor@campus.edu',
      className: 'CS-301',
      semester: 'Spring',
      batch: '2024',
      group: 'B',
      status: 'Active',
      attendanceRate: 88.1,
    ),
    const Student(
      id: 'S-1003',
      name: 'Usman Ali',
      email: 'usman.ali@campus.edu',
      className: 'CS-302',
      semester: 'Spring',
      batch: '2023',
      group: 'A',
      status: 'Active',
      attendanceRate: 84.7,
    ),
    const Student(
      id: 'S-1004',
      name: 'Mariam Zahid',
      email: 'mariam.zahid@campus.edu',
      className: 'CS-303',
      semester: 'Fall',
      batch: '2023',
      group: 'C',
      status: 'On Leave',
      attendanceRate: 76.3,
    ),
    const Student(
      id: 'S-1005',
      name: 'Hassan Raza',
      email: 'hassan.raza@campus.edu',
      className: 'CS-302',
      semester: 'Fall',
      batch: '2022',
      group: 'B',
      status: 'Active',
      attendanceRate: 90.4,
    ),
    const Student(
      id: 'S-1006',
      name: 'Noor Fatima',
      email: 'noor.fatima@campus.edu',
      className: 'CS-304',
      semester: 'Spring',
      batch: '2024',
      group: 'A',
      status: 'Active',
      attendanceRate: 95.2,
    ),
    const Student(
      id: 'S-1007',
      name: 'Bilal Ahmed',
      email: 'bilal.ahmed@campus.edu',
      className: 'CS-303',
      semester: 'Fall',
      batch: '2022',
      group: 'C',
      status: 'Inactive',
      attendanceRate: 61.9,
    ),
    const Student(
      id: 'S-1008',
      name: 'Sara Iqbal',
      email: 'sara.iqbal@campus.edu',
      className: 'CS-301',
      semester: 'Spring',
      batch: '2024',
      group: 'B',
      status: 'Active',
      attendanceRate: 89.6,
    ),
    const Student(
      id: 'S-1009',
      name: 'Talha Yousaf',
      email: 'talha.yousaf@campus.edu',
      className: 'CS-304',
      semester: 'Fall',
      batch: '2023',
      group: 'A',
      status: 'Active',
      attendanceRate: 82.3,
    ),
    const Student(
      id: 'S-1010',
      name: 'Zara Sheikh',
      email: 'zara.sheikh@campus.edu',
      className: 'CS-305',
      semester: 'Spring',
      batch: '2022',
      group: 'C',
      status: 'Active',
      attendanceRate: 91.8,
    ),
  ];

  static final List<AttendanceRecord> attendanceRecords = [
    const AttendanceRecord(
      id: 'A-4001',
      studentName: 'Ayaan Khan',
      date: 'Feb 6, 2026',
      status: 'Present',
      className: 'CS-301',
    ),
    const AttendanceRecord(
      id: 'A-4002',
      studentName: 'Fatima Noor',
      date: 'Feb 6, 2026',
      status: 'Present',
      className: 'CS-301',
    ),
    const AttendanceRecord(
      id: 'A-4003',
      studentName: 'Mariam Zahid',
      date: 'Feb 6, 2026',
      status: 'Absent',
      className: 'CS-303',
    ),
    const AttendanceRecord(
      id: 'A-4004',
      studentName: 'Hassan Raza',
      date: 'Feb 5, 2026',
      status: 'Present',
      className: 'CS-302',
    ),
    const AttendanceRecord(
      id: 'A-4005',
      studentName: 'Noor Fatima',
      date: 'Feb 5, 2026',
      status: 'Present',
      className: 'CS-304',
    ),
  ];

  static final List<ActivityItem> recentActivity = [
    const ActivityItem(
      title: 'CS-301 attendance submitted',
      subtitle: '124 students marked present',
      time: '10 min ago',
    ),
    const ActivityItem(
      title: 'New report generated',
      subtitle: 'Weekly summary for CS-302',
      time: '2 hours ago',
    ),
    const ActivityItem(
      title: 'Student profile updated',
      subtitle: 'Mariam Zahid updated contact details',
      time: 'Yesterday',
    ),
  ];

  static final List<ReportItem> reports = [
    const ReportItem(
      title: 'Weekly Attendance Summary',
      date: 'Feb 5, 2026',
      status: 'Ready',
    ),
    const ReportItem(
      title: 'Class-wise Attendance',
      date: 'Feb 1, 2026',
      status: 'Ready',
    ),
    const ReportItem(
      title: 'Monthly Overview',
      date: 'Jan 31, 2026',
      status: 'Draft',
    ),
  ];

  static final List<SessionHistory> sessions = [
    const SessionHistory(
      id: 'sess-001',
      label: 'Today',
      title: 'Session 10:00 AM',
      className: 'CS-301',
      department: 'Computer Science',
      semester: 'Spring',
      batch: '2024',
      group: 'A',
      marked: 42,
      total: 48,
    ),
    const SessionHistory(
      id: 'sess-002',
      label: 'Yesterday',
      title: 'Session 2:00 PM',
      className: 'CS-302',
      department: 'Computer Science',
      semester: 'Fall',
      batch: '2023',
      group: 'B',
      marked: 37,
      total: 45,
    ),
    const SessionHistory(
      id: 'sess-003',
      label: 'Mar 22',
      title: 'Session 9:00 AM',
      className: 'CS-304',
      department: 'Computer Science',
      semester: 'Spring',
      batch: '2022',
      group: 'C',
      marked: 30,
      total: 40,
    ),
  ];
}
