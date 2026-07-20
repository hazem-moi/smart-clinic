import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/appointment.dart';
import '../models/doctor.dart';
import '../services/api_service.dart';
import '../services/session.dart';
import 'booking_screen.dart';

class PatientDashboard extends StatefulWidget {
  const PatientDashboard({super.key});

  @override
  State<PatientDashboard> createState() => _PatientDashboardState();
}

class _PatientDashboardState extends State<PatientDashboard> {
  late Future<List<Doctor>> _doctorsFuture;
  late Future<List<Appointment>> _appointmentsFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final session = context.read<Session>();
    final api = ApiService(token: session.token);
    _doctorsFuture = api.fetchDoctors();
    _appointmentsFuture = api.fetchPatientAppointments(session.user!.id);
  }

  Future<void> _openBooking(Doctor doctor) async {
    final booked = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => BookingScreen(doctor: doctor)),
    );
    if (booked == true && mounted) {
      setState(_reload);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('أهلاً، ${session.user?.fullName ?? ''}'),
          bottom: const TabBar(tabs: [
            Tab(text: 'الأطباء', icon: Icon(Icons.medical_services_outlined)),
            Tab(text: 'مواعيدي', icon: Icon(Icons.event_note_outlined)),
          ]),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'تسجيل الخروج',
              onPressed: () => context.read<Session>().logout(),
            ),
          ],
        ),
        body: TabBarView(
          children: [
            _DoctorsTab(future: _doctorsFuture, onBook: _openBooking),
            _AppointmentsTab(future: _appointmentsFuture, onRefresh: () async => setState(_reload)),
          ],
        ),
      ),
    );
  }
}

class _DoctorsTab extends StatelessWidget {
  final Future<List<Doctor>> future;
  final void Function(Doctor) onBook;

  const _DoctorsTab({required this.future, required this.onBook});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Doctor>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('تعذر تحميل قائمة الأطباء: ${snapshot.error}'));
        }
        final doctors = snapshot.data ?? [];
        if (doctors.isEmpty) {
          return const Center(child: Text('لا يوجد أطباء متاحون حالياً'));
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 700;
            final padding = const EdgeInsets.all(16);

            if (isWide) {
              return GridView.builder(
                padding: padding,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 3.2,
                ),
                itemCount: doctors.length,
                itemBuilder: (context, i) => _DoctorCard(doctor: doctors[i], onBook: onBook),
              );
            }

            return ListView.separated(
              padding: padding,
              itemCount: doctors.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) => _DoctorCard(doctor: doctors[i], onBook: onBook),
            );
          },
        );
      },
    );
  }
}

class _DoctorCard extends StatelessWidget {
  final Doctor doctor;
  final void Function(Doctor) onBook;

  const _DoctorCard({required this.doctor, required this.onBook});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(radius: 26, child: Text(doctor.fullName.isNotEmpty ? doctor.fullName[0] : '؟')),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(doctor.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(doctor.specialty),
                  Text('الكشفية: ${doctor.consultationFee.toStringAsFixed(0)}'),
                ],
              ),
            ),
            FilledButton(onPressed: () => onBook(doctor), child: const Text('حجز موعد')),
          ],
        ),
      ),
    );
  }
}

class _AppointmentsTab extends StatelessWidget {
  final Future<List<Appointment>> future;
  final Future<void> Function() onRefresh;

  const _AppointmentsTab({required this.future, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Appointment>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('تعذر تحميل المواعيد: ${snapshot.error}'));
        }
        final appointments = snapshot.data ?? [];

        return RefreshIndicator(
          onRefresh: onRefresh,
          child: appointments.isEmpty
              ? ListView(
                  children: const [
                    SizedBox(height: 120),
                    Center(child: Text('لا توجد مواعيد بعد، احجز موعدك الأول من تبويب الأطباء')),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: appointments.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final a = appointments[i];
                    return Card(
                      child: ListTile(
                        title: Text('${a.doctorName ?? ''} — ${a.specialty ?? ''}'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(DateFormat('yyyy/MM/dd — HH:mm').format(a.appointmentDate)),
                            Text('الحالة: ${Appointment.statusLabel(a.status)}'),
                            if (a.doctorNotes != null && a.doctorNotes!.isNotEmpty)
                              Text('الوصفة: ${a.doctorNotes}'),
                          ],
                        ),
                        isThreeLine: a.doctorNotes != null && a.doctorNotes!.isNotEmpty,
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}
