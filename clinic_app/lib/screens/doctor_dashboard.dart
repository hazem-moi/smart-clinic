import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../models/appointment.dart';
import '../services/api_service.dart';
import '../services/session.dart';
import '../widgets/status_chip.dart';

class DoctorDashboard extends StatefulWidget {
  const DoctorDashboard({super.key});

  @override
  State<DoctorDashboard> createState() => _DoctorDashboardState();
}

class _DoctorDashboardState extends State<DoctorDashboard> {
  late Future<List<Appointment>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final session = context.read<Session>();
    final api = ApiService(token: session.token);
    _future = api.fetchDoctorAppointments(session.user!.doctorId!, todayOnly: true);
  }

  Future<void> _updateStatus(Appointment a, String status) async {
    final session = context.read<Session>();
    try {
      await ApiService(token: session.token).updateAppointmentStatus(a.id, status);
      if (mounted) setState(_reload);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _writeNotes(Appointment a) async {
    final controller = TextEditingController(text: a.doctorNotes ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('الملاحظة الطبية / الوصفة'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(hintText: 'اكتب الوصفة أو الملاحظة هنا'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('حفظ')),
        ],
      ),
    );

    if (saved != true || !mounted) return;
    final session = context.read<Session>();
    try {
      await ApiService(token: session.token).saveDoctorNotes(a.id, controller.text);
      if (mounted) setState(_reload);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();

    return Scaffold(
      appBar: AppBar(
        title: Text('مواعيد اليوم — د. ${session.user?.fullName ?? ''}'),
        actions: [
          const ThemeToggleButton(),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'تسجيل الخروج',
            onPressed: () => context.read<Session>().logout(),
          ),
        ],
      ),
      body: FutureBuilder<List<Appointment>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('تعذر تحميل المواعيد: ${snapshot.error}'));
          }
          final appointments = snapshot.data ?? [];

          return RefreshIndicator(
            onRefresh: () async => setState(_reload),
            child: appointments.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 120),
                      Center(child: Text('لا توجد مواعيد اليوم')),
                    ],
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: appointments
                        .map((a) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _AppointmentCard(
                                appointment: a,
                                onStatusChange: (s) => _updateStatus(a, s),
                                onWriteNotes: () => _writeNotes(a),
                              ),
                            ))
                        .toList(),
                  ),
          );
        },
      ),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  final Appointment appointment;
  final void Function(String) onStatusChange;
  final VoidCallback onWriteNotes;

  const _AppointmentCard({
    required this.appointment,
    required this.onStatusChange,
    required this.onWriteNotes,
  });

  @override
  Widget build(BuildContext context) {
    final actions = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton(
          onPressed: () => onStatusChange('confirmed'),
          child: const Text('قبول'),
        ),
        OutlinedButton(
          onPressed: () => onStatusChange('cancelled'),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: onWriteNotes,
          child: const Text('تم الفحص + كتابة الوصفة'),
        ),
      ],
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(appointment.patientName ?? '',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                StatusChip(status: appointment.status),
              ],
            ),
            const SizedBox(height: 4),
            Text(DateFormat('yyyy/MM/dd — HH:mm').format(appointment.appointmentDate)),
            if (appointment.doctorNotes != null && appointment.doctorNotes!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('الوصفة السابقة: ${appointment.doctorNotes}'),
              ),
            const SizedBox(height: 12),
            actions,
          ],
        ),
      ),
    );
  }
}
