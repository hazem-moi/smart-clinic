import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/doctor.dart';
import '../services/api_service.dart';
import '../services/session.dart';

class BookingScreen extends StatefulWidget {
  final Doctor doctor;
  const BookingScreen({super.key, required this.doctor});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  DateTime? _date;
  TimeOfDay? _time;
  bool _submitting = false;
  String? _error;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 180)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _confirm() async {
    if (_date == null || _time == null) {
      setState(() => _error = 'يرجى اختيار التاريخ والوقت');
      return;
    }
    final dateTime = DateTime(_date!.year, _date!.month, _date!.day, _time!.hour, _time!.minute);
    if (dateTime.isBefore(DateTime.now())) {
      setState(() => _error = 'لا يمكن اختيار وقت في الماضي');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final session = context.read<Session>();
      await ApiService(token: session.token).bookAppointment(doctorId: widget.doctor.id, dateTime: dateTime);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حجز الموعد بنجاح')));
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('حجز موعد')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.doctor.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        Text(widget.doctor.specialty),
                        Text('سعر الكشفية: ${widget.doctor.consultationFee.toStringAsFixed(0)}'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text(_date == null ? 'اختر التاريخ' : DateFormat('yyyy/MM/dd').format(_date!)),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _pickTime,
                  icon: const Icon(Icons.access_time_outlined),
                  label: Text(_time == null ? 'اختر الوقت' : _time!.format(context)),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _submitting ? null : _confirm,
                  child: _submitting
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('تأكيد الحجز'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
