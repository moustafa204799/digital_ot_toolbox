import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; 

import '../database/database_helper.dart'; // ✅ تم تصحيح المسار
import '../models/patient.dart'; // ✅ تم تصحيح المسار

class AddPatientScreen extends StatefulWidget {
  const AddPatientScreen({super.key});

  @override
  State<AddPatientScreen> createState() => _AddPatientScreenState();
}

class _AddPatientScreenState extends State<AddPatientScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _diagnosisController = TextEditingController();
  final _dobController = TextEditingController();
  
  DateTime? _selectedDate;
  String? _selectedGender;

  // دالة لاختيار تاريخ الميلاد
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        // تنسيق التاريخ وحفظه في المتحكم (Controller)
        // سنستخدم تنسيق ISO 8601 (YYYY-MM-DD) للحفظ في قاعدة البيانات
        _dobController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  // دالة لحفظ المريض في قاعدة البيانات
  void _savePatient() async {
    if (_formKey.currentState!.validate() && _selectedDate != null) {
      final newPatient = Patient(
        fullName: _nameController.text,
        diagnosis: _diagnosisController.text.isNotEmpty ? _diagnosisController.text : null,
        dob: _dobController.text,
        gender: _selectedGender,
      );

      final id = await DatabaseHelper.instance.insertPatient(newPatient);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم إضافة المريض: ${newPatient.fullName} برقم $id')),
        );
        // العودة إلى الشاشة السابقة (ستكون شاشة لوحة التحكم أو قائمة المرضى)
        Navigator.of(context).pop();
      }
    } else if (_selectedDate == null) {
       ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('الرجاء اختيار تاريخ الميلاد')),
        );
    }
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _diagnosisController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('➕ إضافة مريض جديد'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // حقل الاسم الكامل
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'الاسم الكامل للمريض *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'الاسم مطلوب';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // حقل تاريخ الميلاد
              TextFormField(
                controller: _dobController,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'تاريخ الميلاد *',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: () => _selectDate(context),
                  ),
                ),
                validator: (value) {
                  if (_selectedDate == null) {
                    return 'تاريخ الميلاد مطلوب';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // حقل التشخيص (اختياري)
              TextFormField(
                controller: _diagnosisController,
                decoration: const InputDecoration(
                  labelText: 'التشخيص (مثل: CP، تأخر نمو)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // اختيار الجنس
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'الجنس (اختياري)',
                  border: OutlineInputBorder(),
                ),
                initialValue: _selectedGender,
                items: const [
                  DropdownMenuItem(value: 'ذكر', child: Text('ذكر 👦')),
                  DropdownMenuItem(value: 'أنثى', child: Text('أنثى 👧')),
                ],
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedGender = newValue;
                  });
                },
              ),
              const SizedBox(height: 30),

              // زر الحفظ
              ElevatedButton.icon(
                onPressed: _savePatient,
                icon: const Icon(Icons.person_add),
                label: const Text('حفظ وإضافة المريض', style: TextStyle(fontSize: 18)),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}  