import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../models/patient.dart';

class ScheduleAppointmentScreen extends StatefulWidget {
  final Patient patient;

  const ScheduleAppointmentScreen({super.key, required this.patient});

  @override
  State<ScheduleAppointmentScreen> createState() => _ScheduleAppointmentScreenState();
}

class _ScheduleAppointmentScreenState extends State<ScheduleAppointmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _notesController = TextEditingController();
  
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now, // لا يمكن اختيار تاريخ في الماضي
      lastDate: DateTime(now.year + 2),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Colors.blue),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      setState(() {
        _selectedDate = pickedDate;
      });
    }
  }

  Future<void> _pickTime() async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Colors.blue),
          ),
          child: child!,
        );
      },
    );

    if (pickedTime != null) {
      setState(() {
        _selectedTime = pickedTime;
      });
    }
  }

  Future<void> _saveAppointment() async {
    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار التاريخ والوقت')),
      );
      return;
    }

    if (_formKey.currentState!.validate()) {
      // دمج التاريخ والوقت في كائن DateTime واحد
      final fullDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );

      final appointment = {
        'patient_id': widget.patient.patientId,
        'appointment_date': fullDateTime.toIso8601String(),
        'notes': _notesController.text,
      };

      await DatabaseHelper.instance.insertAppointment(appointment);

      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم جدولة الموعد بنجاح')),
      );
      Navigator.of(context).pop(); // العودة للملف الشخصي
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('جدولة موعد متابعة'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // بطاقة معلومات المريض
                Card(
                  color: Colors.blue.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        const Icon(Icons.calendar_month, size: 40, color: Colors.blue),
                        const SizedBox(height: 10),
                        Text(
                          'حجز موعد لـ: ${widget.patient.fullName}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // اختيار التاريخ
                ListTile(
                  title: Text(
                    _selectedDate == null
                        ? 'اختر التاريخ'
                        : 'التاريخ: ${DateFormat('yyyy-MM-dd').format(_selectedDate!)}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  trailing: const Icon(Icons.date_range, color: Colors.blue),
                  onTap: _pickDate,
                  shape: RoundedRectangleBorder(
                    side: const BorderSide(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 16),

                // اختيار الوقت
                ListTile(
                  title: Text(
                    _selectedTime == null
                        ? 'اختر الوقت'
                        : 'الوقت: ${_selectedTime!.format(context)}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  trailing: const Icon(Icons.access_time, color: Colors.orange),
                  onTap: _pickTime,
                  shape: RoundedRectangleBorder(
                    side: const BorderSide(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 24),

                // حقل الملاحظات
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظات (اختياري)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.note),
                    hintText: 'مثال: إحضار التقرير السابق، جلسة تقييم...',
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 32),

                // زر الحفظ
                ElevatedButton.icon(
                  onPressed: _saveAppointment,
                  icon: const Icon(Icons.save, color: Colors.white),
                  label: const Text('حفظ الموعد', style: TextStyle(fontSize: 18, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}