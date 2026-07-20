import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../models/appointment.dart';
import '../models/doctor.dart';
import '../services/api_service.dart';
import '../services/session.dart';
import '../widgets/status_chip.dart';
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

  Future<void> _cancel(Appointment a) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إلغاء الموعد'),
        content: const Text('هل أنت متأكد من إلغاء هذا الموعد؟'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('تراجع')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('نعم، ألغِ')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ApiService(token: context.read<Session>().token).cancelAppointment(a.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إلغاء الموعد')));
      setState(_reload);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _rate(Appointment a) async {
    final result = await showDialog<({int rating, String comment})>(
      context: context,
      builder: (context) => _RatingDialog(doctorName: a.doctorName ?? ''),
    );
    if (result == null || !mounted) return;

    try {
      await ApiService(token: context.read<Session>().token)
          .submitReview(appointmentId: a.id, rating: result.rating, comment: result.comment);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('شكراً لتقييمك')));
      setState(_reload);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
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
            const ThemeToggleButton(),
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
            _AppointmentsTab(
              future: _appointmentsFuture,
              onRefresh: () async => setState(_reload),
              onCancel: _cancel,
              onRate: _rate,
            ),
          ],
        ),
      ),
    );
  }
}

class _DoctorsTab extends StatefulWidget {
  final Future<List<Doctor>> future;
  final void Function(Doctor) onBook;

  const _DoctorsTab({required this.future, required this.onBook});

  @override
  State<_DoctorsTab> createState() => _DoctorsTabState();
}

class _DoctorsTabState extends State<_DoctorsTab> {
  String _specialtyFilter = 'الكل';

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Doctor>>(
      future: widget.future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('تعذر تحميل قائمة الأطباء: ${snapshot.error}'));
        }
        final allDoctors = snapshot.data ?? [];
        if (allDoctors.isEmpty) {
          return const Center(child: Text('لا يوجد أطباء متاحون حالياً'));
        }

        final specialties = ['الكل', ...{for (final d in allDoctors) d.specialty}];
        if (!specialties.contains(_specialtyFilter)) _specialtyFilter = 'الكل';
        final doctors = _specialtyFilter == 'الكل'
            ? allDoctors
            : allDoctors.where((d) => d.specialty == _specialtyFilter).toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: DropdownButtonFormField<String>(
                initialValue: _specialtyFilter,
                decoration: const InputDecoration(labelText: 'تصفية حسب التخصص'),
                items: specialties.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (v) => setState(() => _specialtyFilter = v ?? 'الكل'),
              ),
            ),
            Expanded(child: _buildList(doctors)),
          ],
        );
      },
    );
  }

  Widget _buildList(List<Doctor> doctors) {
    if (doctors.isEmpty) {
      return const Center(child: Text('لا يوجد أطباء في هذا التخصص'));
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 700;
        const padding = EdgeInsets.all(16);

        if (isWide) {
          return GridView.builder(
            padding: padding,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 3.0,
            ),
            itemCount: doctors.length,
            itemBuilder: (context, i) => _DoctorCard(doctor: doctors[i], onBook: widget.onBook),
          );
        }

        return ListView.separated(
          padding: padding,
          itemCount: doctors.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, i) => _DoctorCard(doctor: doctors[i], onBook: widget.onBook),
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
                  _RatingLine(avg: doctor.avgRating, count: doctor.reviewsCount),
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

class _RatingLine extends StatelessWidget {
  final double? avg;
  final int count;
  const _RatingLine({required this.avg, required this.count});

  @override
  Widget build(BuildContext context) {
    if (avg == null || count == 0) {
      return const Text('لا توجد تقييمات بعد', style: TextStyle(fontSize: 12, color: Colors.grey));
    }
    return Row(
      children: [
        const Icon(Icons.star, size: 16, color: Color(0xFFF5A623)),
        const SizedBox(width: 4),
        Text('${avg!.toStringAsFixed(1)} ($count)', style: const TextStyle(fontSize: 13)),
      ],
    );
  }
}

class _AppointmentsTab extends StatelessWidget {
  final Future<List<Appointment>> future;
  final Future<void> Function() onRefresh;
  final void Function(Appointment) onCancel;
  final void Function(Appointment) onRate;

  const _AppointmentsTab({
    required this.future,
    required this.onRefresh,
    required this.onCancel,
    required this.onRate,
  });

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
                    return _PatientAppointmentCard(appointment: a, onCancel: onCancel, onRate: onRate);
                  },
                ),
        );
      },
    );
  }
}

class _PatientAppointmentCard extends StatelessWidget {
  final Appointment appointment;
  final void Function(Appointment) onCancel;
  final void Function(Appointment) onRate;

  const _PatientAppointmentCard({required this.appointment, required this.onCancel, required this.onRate});

  @override
  Widget build(BuildContext context) {
    final a = appointment;
    final hasNotes = a.doctorNotes != null && a.doctorNotes!.isNotEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('${a.doctorName ?? ''} — ${a.specialty ?? ''}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                StatusChip(status: a.status),
              ],
            ),
            const SizedBox(height: 4),
            Text(DateFormat('yyyy/MM/dd — HH:mm').format(a.appointmentDate)),
            if (hasNotes)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('الوصفة: ${a.doctorNotes}'),
              ),
            if (a.myRating != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    const Text('تقييمك: '),
                    ...List.generate(
                      5,
                      (i) => Icon(
                        i < a.myRating! ? Icons.star : Icons.star_border,
                        size: 16,
                        color: const Color(0xFFF5A623),
                      ),
                    ),
                  ],
                ),
              ),
            if (a.isCancellable || a.canReview) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  if (a.isCancellable)
                    OutlinedButton(onPressed: () => onCancel(a), child: const Text('إلغاء الموعد')),
                  if (a.canReview)
                    FilledButton.tonal(onPressed: () => onRate(a), child: const Text('قيّم الطبيب')),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RatingDialog extends StatefulWidget {
  final String doctorName;
  const _RatingDialog({required this.doctorName});

  @override
  State<_RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<_RatingDialog> {
  int _rating = 5;
  final _commentCtrl = TextEditingController();

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('تقييم ${widget.doctorName}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final value = i + 1;
              return IconButton(
                onPressed: () => setState(() => _rating = value),
                icon: Icon(
                  value <= _rating ? Icons.star : Icons.star_border,
                  color: const Color(0xFFF5A623),
                  size: 32,
                ),
              );
            }),
          ),
          TextField(
            controller: _commentCtrl,
            decoration: const InputDecoration(hintText: 'تعليق (اختياري)'),
            maxLines: 2,
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('إلغاء')),
        FilledButton(
          onPressed: () => Navigator.of(context).pop((rating: _rating, comment: _commentCtrl.text)),
          child: const Text('إرسال'),
        ),
      ],
    );
  }
}
