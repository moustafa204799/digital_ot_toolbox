import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../database/database_helper.dart';
import '../models/patient.dart';
import 'patient_profile_screen.dart';
import 'add_patient_screen.dart';

class PatientListScreen extends StatefulWidget {
  const PatientListScreen({super.key});

  @override
  State<PatientListScreen> createState() => _PatientListScreenState();
}

class _PatientListScreenState extends State<PatientListScreen> {
  List<Patient> _patients = [];
  List<Patient> _filteredPatients = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPatients();
    _searchController.addListener(_filterPatients);
  }

  // تحميل قائمة المرضى من قاعدة البيانات
  void _loadPatients() async {
    final list = await DatabaseHelper.instance.getPatients();
    if (mounted) {
      setState(() {
        _patients = list;
        _filteredPatients = list; // في البداية، القائمة المصفاة هي نفس القائمة الأصلية
        _isLoading = false;
      });
    }
  }

  // تصفية القائمة بناءً على نص البحث
  void _filterPatients() {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) {
      setState(() => _filteredPatients = _patients);
    } else {
      setState(() {
        _filteredPatients = _patients.where((p) {
          return p.fullName.toLowerCase().contains(query);
        }).toList();
      });
    }
  }

  // حذف مريض وتحديث القائمة
  Future<void> _deletePatient(int id) async {
    await DatabaseHelper.instance.deletePatient(id);
    _loadPatients(); // إعادة التحميل
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حذف المريض وجميع بياناته بنجاح')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('قائمة المرضى', style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // --- شريط البحث ---
          Padding(
            padding: EdgeInsets.all(12.w),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'بحث عن مريض...',
                hintText: 'اكتب اسم المريض',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.r),
                ),
                contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 12.w),
              ),
            ),
          ),
          
          // --- قائمة المرضى ---
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredPatients.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.person_search, size: 60.w, color: Colors.grey),
                            SizedBox(height: 10.h),
                            Text(
                              'لا يوجد مرضى مطابقين', 
                              style: TextStyle(fontSize: 16.sp, color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.only(bottom: 80.h), // مساحة للزر العائم
                        itemCount: _filteredPatients.length,
                        itemBuilder: (context, index) {
                          final patient = _filteredPatients[index];
                          return Card(
                            margin: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                            child: ListTile(
                              leading: CircleAvatar(
                                radius: 24.r,
                                backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                                child: Text(
                                  patient.fullName.isNotEmpty ? patient.fullName[0].toUpperCase() : '?',
                                  style: TextStyle(
                                    color: Theme.of(context).primaryColor, 
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18.sp,
                                  ),
                                ),
                              ),
                              title: Text(
                                patient.fullName, 
                                style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                'العمر: ${patient.calculateAge()}', 
                                style: TextStyle(fontSize: 14.sp),
                              ),
                              trailing: IconButton(
                                icon: Icon(Icons.delete_outline, color: Colors.red, size: 24.w),
                                onPressed: () => _showDeleteConfirmation(patient),
                              ),
                              onTap: () {
                                // الانتقال إلى ملف المريض
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => PatientProfileScreen(patient: patient),
                                  ),
                                ).then((_) => _loadPatients()); // تحديث عند العودة (قد يكون تم تعديل البيانات)
                              },
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddPatientScreen()),
          ).then((_) => _loadPatients());
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  // نافذة تأكيد الحذف
  void _showDeleteConfirmation(Patient patient) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('هل أنت متأكد من رغبتك في حذف ملف "${patient.fullName}"؟\nسيتم حذف جميع التقييمات والتقارير المرتبطة به نهائياً.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx), 
            child: const Text('إلغاء'),
          ),
          TextButton(
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
            onPressed: () {
              Navigator.pop(ctx);
              _deletePatient(patient.patientId!);
            },
          ),
        ],
      ),
    );
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}