import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:call_companion/models/user.dart';
import 'package:call_companion/providers/auth_provider.dart';
import 'package:call_companion/screens/employee/employee_dashboard.dart';
import 'package:call_companion/screens/admin/admin_dashboard.dart';

class RoleSelectScreen extends StatefulWidget {
  const RoleSelectScreen({super.key});

  @override
  State<RoleSelectScreen> createState() => _RoleSelectScreenState();
}

class _RoleSelectScreenState extends State<RoleSelectScreen> {
  UserRole? _selected;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    _selected = user?.role ?? UserRole.employee;
  }

  Future<void> _continue() async {
    final auth = context.read<AuthProvider>();
    if (_selected == null || auth.user == null) return;
    setState(() => _saving = true);
    await auth.completeRoleSelection(_selected!);
    if (!mounted) return;
    setState(() => _saving = false);
    if (_selected == UserRole.admin) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AdminDashboard()),
        (route) => false,
      );
    } else {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const EmployeeDashboard()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select account type')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Choose how you want to use Call Companion'),
            const SizedBox(height: 16),
            RadioListTile<UserRole>(
              value: UserRole.employee,
              groupValue: _selected,
              onChanged: (v) => setState(() => _selected = v),
              title: const Text('Employee'),
            ),
            RadioListTile<UserRole>(
              value: UserRole.admin,
              groupValue: _selected,
              onChanged: (v) => setState(() => _selected = v),
              title: const Text('Admin'),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _continue,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Continue'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
