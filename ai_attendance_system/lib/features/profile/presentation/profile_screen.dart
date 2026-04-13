import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_spacing.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../shared/services/api_service.dart';
import '../../../shared/services/mock_data_service.dart';
import '../../../shared/services/session_store.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final TextEditingController _apiController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _apiController = TextEditingController(
      text: SessionStore.apiBaseUrl ?? ApiService.defaultBaseUrl,
    );
  }

  @override
  void dispose() {
    _apiController.dispose();
    super.dispose();
  }

  Future<void> _saveApiUrl() async {
    final input = _apiController.text.trim();
    if (input.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('API URL cannot be empty')));
      return;
    }
    if (!input.startsWith('http://') && !input.startsWith('https://')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('API URL must start with http:// or https://')),
      );
      return;
    }
    setState(() => _saving = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_base_url', input);
    SessionStore.apiBaseUrl = input;
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('API URL updated')));
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveLayout.isDesktop(MediaQuery.of(context).size.width);
    final padding = EdgeInsets.all(isDesktop ? 24 : 16);
    final students = MockDataService.students;
    final total = students.length;
    final present = students.where((s) => s.status == 'Active').length;
    final absent = total - present;
    final breakdown = _reportStudents;

    return SingleChildScrollView(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Session Report',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          AppSpacing.gap8,
          Text(
            'Attendance Report • Today 9:00 AM',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppTheme.textSecondaryFor(context)),
          ),
          AppSpacing.gap16,
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  title: 'Present',
                  value: present.toString(),
                  color: AppTheme.brandGreen,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  title: 'Absent',
                  value: absent.toString(),
                  color: AppTheme.accentOrange,
                ),
              ),
            ],
          ),
          AppSpacing.gap16,
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Student Breakdown',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                AppSpacing.gap12,
                ListView.separated(
                  itemCount: breakdown.length,
                  separatorBuilder: (_, _) => const Divider(height: 24),
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemBuilder: (context, index) {
                    final student = breakdown[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: student.color.withOpacity(0.14),
                        child: Text(student.initials),
                      ),
                      title: Text(student.name),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _StatusPill(label: student.status, color: student.color),
                          const SizedBox(width: 8),
                          Icon(
                            student.present ? Icons.check_circle : Icons.cancel,
                            color: student.present
                                ? AppTheme.brandGreen
                                : AppTheme.accentOrange,
                            size: 18,
                          ),
                        ],
                      ),
                    );
                  },
                ),
                AppSpacing.gap12,
                _EndpointPill(label: 'GET  /attendance/sessions/{id}/report'),
              ],
            ),
          ),
          AppSpacing.gap16,
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'API Settings',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                AppSpacing.gap12,
                AppTextField(
                  label: 'API Base URL',
                  hintText: 'https://your-backend.ngrok-free.dev',
                  controller: _apiController,
                  requiredField: false,
                ),
                AppSpacing.gap12,
                AppButton(
                  label: _saving ? 'Saving...' : 'Save',
                  onPressed: _saving ? null : _saveApiUrl,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.title, required this.value, required this.color});

  final String title;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: AppTheme.textSecondaryFor(context)),
          ),
          AppSpacing.gap8,
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _EndpointPill extends StatelessWidget {
  const _EndpointPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAltFor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderFor(context)),
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: AppTheme.textSecondaryFor(context)),
      ),
    );
  }
}

class _ReportStudent {
  const _ReportStudent({
    required this.name,
    required this.status,
    required this.present,
    required this.color,
  });

  final String name;
  final String status;
  final bool present;
  final Color color;

  String get initials {
    final parts = name.split(' ');
    if (parts.length == 1) return parts.first.substring(0, 1);
    return parts.take(2).map((part) => part.substring(0, 1)).join();
  }
}

const List<_ReportStudent> _reportStudents = [
  _ReportStudent(
    name: 'Ahmed Khan',
    status: 'Engaged',
    present: true,
    color: AppTheme.brandGreen,
  ),
  _ReportStudent(
    name: 'Sara Riaz',
    status: 'Using Phone',
    present: true,
    color: AppTheme.accentOrange,
  ),
  _ReportStudent(
    name: 'Usman Malik',
    status: 'Sleeping',
    present: true,
    color: AppTheme.accentPurple,
  ),
  _ReportStudent(
    name: 'Fatima Ali',
    status: 'Absent',
    present: false,
    color: AppTheme.danger,
  ),
];
