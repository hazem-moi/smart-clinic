import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_user.dart';
import '../models/doctor.dart';
import '../services/api_service.dart';
import '../services/session.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _mailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _feeCtrl = TextEditingController();

  String _role = 'patient';
  int? _specialtyId;
  List<Specialty> _specialties = [];
  bool _loadingSpecialties = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSpecialties();
  }

  Future<void> _loadSpecialties() async {
    try {
      final list = await ApiService().fetchSpecialties();
      if (!mounted) return;
      setState(() {
        _specialties = list;
        _loadingSpecialties = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingSpecialties = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _mailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    _feeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_role == 'doctor' && _specialtyId == null) {
      setState(() => _error = 'يرجى اختيار التخصص');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final result = await ApiService().register(
        fullName: _nameCtrl.text.trim(),
        mail: _mailCtrl.text.trim(),
        password: _passCtrl.text,
        role: _role,
        specialtyId: _role == 'doctor' ? _specialtyId : null,
        consultationFee: _role == 'doctor' ? double.tryParse(_feeCtrl.text) ?? 0 : null,
      );
      final user = AppUser.fromJson({...result['user'] as Map<String, dynamic>, 'role': _role});
      if (!mounted) return;
      await context.read<Session>().login(result['token'] as String, user);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إنشاء حساب جديد')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'patient', label: Text('مريض'), icon: Icon(Icons.person_outline)),
                        ButtonSegment(value: 'doctor', label: Text('طبيب'), icon: Icon(Icons.medical_services_outlined)),
                      ],
                      selected: {_role},
                      onSelectionChanged: (s) => setState(() => _role = s.first),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(labelText: 'الاسم الكامل'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'يرجى إدخال الاسم' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _mailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'البريد الإلكتروني'),
                      validator: (v) => (v == null || !v.contains('@')) ? 'أدخل بريداً إلكترونياً صحيحاً' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'كلمة السر'),
                      validator: (v) => (v == null || v.length < 6) ? 'كلمة السر 6 أحرف على الأقل' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirmCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'تأكيد كلمة السر'),
                      validator: (v) => (v != _passCtrl.text) ? 'كلمتا السر غير متطابقتين' : null,
                    ),
                    if (_role == 'doctor') ...[
                      const SizedBox(height: 16),
                      _loadingSpecialties
                          ? const Center(child: CircularProgressIndicator())
                          : DropdownButtonFormField<int>(
                              initialValue: _specialtyId,
                              decoration: const InputDecoration(labelText: 'التخصص'),
                              items: _specialties
                                  .map((s) => DropdownMenuItem(value: s.id, child: Text(s.name)))
                                  .toList(),
                              onChanged: (v) => setState(() => _specialtyId = v),
                            ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _feeCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'سعر الكشفية'),
                        validator: (v) {
                          if (_role != 'doctor') return null;
                          if (v == null || v.trim().isEmpty) return 'يرجى إدخال سعر الكشفية';
                          if (double.tryParse(v) == null) return 'أدخل رقماً صحيحاً';
                          return null;
                        },
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _submitting ? null : _submit,
                      child: _submitting
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('إنشاء الحساب'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
