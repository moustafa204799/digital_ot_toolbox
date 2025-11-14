import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart'; // 🆕
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
  final _notesController = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _saveAppointment() async {
    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اختر الوقت والتاريخ')));
      return;
    }
    if (_formKey.currentState!.validate()) {
      final dt = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day, _selectedTime!.hour, _selectedTime!.minute);
      await DatabaseHelper.instance.insertAppointment({
        'patient_id': widget.patient.patientId,
        'appointment_date': dt.toIso8601String(),
        'notes': _notesController.text,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الحجز ✅')));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(title: Text('حجز موعد', style: TextStyle(fontSize: 20.sp))),
      body: Padding(
        padding: EdgeInsets.all(16.w),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Card(
                color: isDark ? Colors.grey[800] : Colors.blue.shade50, // ✅
                child: Padding(
                  padding: EdgeInsets.all(16.w),
                  child: Column(
                    children: [
                      Icon(Icons.event, size: 40.w, color: Colors.blue),
                      SizedBox(height: 10.h),
                      Text('موعد لـ: ${widget.patient.fullName}', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 24.h),
              
              ListTile(
                title: Text(_selectedDate == null ? 'اختر التاريخ' : DateFormat('yyyy-MM-dd').format(_selectedDate!), style: TextStyle(fontSize: 16.sp)),
                trailing: const Icon(Icons.calendar_today, color: Colors.blue),
                onTap: () async {
                  final d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                  if (d != null) setState(() => _selectedDate = d);
                },
                shape: RoundedRectangleBorder(side: const BorderSide(color: Colors.grey), borderRadius: BorderRadius.circular(8.r)),
              ),
              SizedBox(height: 16.h),
              
              ListTile(
                title: Text(_selectedTime == null ? 'اختر الوقت' : _selectedTime!.format(context), style: TextStyle(fontSize: 16.sp)),
                trailing: const Icon(Icons.access_time, color: Colors.orange),
                onTap: () async {
                  final t = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                  if (t != null) setState(() => _selectedTime = t);
                },
                shape: RoundedRectangleBorder(side: const BorderSide(color: Colors.grey), borderRadius: BorderRadius.circular(8.r)),
              ),
              SizedBox(height: 24.h),
              
              TextFormField(
                controller: _notesController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'ملاحظات', border: OutlineInputBorder(), prefixIcon: Icon(Icons.note)),
              ),
              const Spacer(),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saveAppointment,
                  icon: const Icon(Icons.save, color: Colors.white),
                  label: Text('حفظ الموعد', style: TextStyle(fontSize: 18.sp, color: Colors.white)),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, padding: EdgeInsets.symmetric(vertical: 14.h)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}