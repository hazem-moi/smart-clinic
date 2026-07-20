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
  String? _selectedSlot; // "HH:mm"
  List<String> _slots = [];
  bool _loadingSlots = false;
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
    if (picked != null) {
      setState(() {
        _date = picked;
        _selectedSlot = null;
        _error = null;
      });
      await _loadSlots();
    }
  }

  Future<void> _loadSlots() async {
    if (_date == null) return;
    setState(() {
      _loadingSlots = true;
      _slots = [];
    });
    try {
      final session = context.read<Session>();
      final booked = await ApiService(token: session.token).fetchBookedSlots(widget.doctor.id, _date!);
      setState(() => _slots = _generateSlots(booked));
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loadingSlots = false);
    }
  }

  // يولّد خانات الدوام مستبعداً المحجوزة والماضية (إن كان التاريخ اليوم)
  List<String> _generateSlots(Set<String> booked) {
    final d = widget.doctor;
    final now = DateTime.now();
    final isToday = _date!.year == now.year && _date!.month == now.month && _date!.day == now.day;
    final slots = <String>[];
    for (var h = d.workStartHour; h < d.workEndHour; h++) {
      for (var m = 0; m < 60; m += d.slotMinutes) {
        final label = '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
        if (booked.contains(label)) continue;
        if (isToday && DateTime(_date!.year, _date!.month, _date!.day, h, m).isBefore(now)) continue;
        slots.add(label);
      }
    }
    return slots;
  }

  Future<void> _confirm() async {
    if (_date == null || _selectedSlot == null) {
      setState(() => _error = 'يرجى اختيار التاريخ والوقت');
      return;
    }
    final parts = _selectedSlot!.split(':');
    final dateTime = DateTime(_date!.year, _date!.month, _date!.day, int.parse(parts[0]), int.parse(parts[1]));

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
            constraints: const BoxConstraints(maxWidth: 480),
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
                        Text(
                          'الدوام: ${widget.doctor.workStartHour}:00 - ${widget.doctor.workEndHour}:00',
                          style: const TextStyle(fontSize: 13),
                        ),
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
                const SizedBox(height: 16),
                if (_date != null) _buildSlotSection(),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: (_submitting || _selectedSlot == null) ? null : _confirm,
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

  Widget _buildSlotSection() {
    if (_loadingSlots) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_slots.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text('لا توجد أوقات متاحة في هذا اليوم، جرّب تاريخاً آخر'),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('الأوقات المتاحة:', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _slots.map((slot) {
            return ChoiceChip(
              label: Text(slot),
              selected: _selectedSlot == slot,
              onSelected: (_) => setState(() => _selectedSlot = slot),
            );
          }).toList(),
        ),
      ],
    );
  }
}
