import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/patient.dart';
import 'add_patient_screen.dart'; 
import 'patient_profile_screen.dart'; 

class PatientListScreen extends StatefulWidget {
  const PatientListScreen({super.key});

  @override
  State<PatientListScreen> createState() => _PatientListScreenState();
}

class _PatientListScreenState extends State<PatientListScreen> {
  late Future<List<Patient>> _patientsFuture;
  List<Patient> _allPatients = [];
  List<Patient> _filteredPatients = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _patientsFuture = _loadPatients();
    _searchController.addListener(_filterPatients);
  }

  Future<List<Patient>> _loadPatients() async {
    final patients = await DatabaseHelper.instance.getPatients();
    setState(() {
      _allPatients = patients;
      _filteredPatients = patients; 
    });
    return patients;
  }

  void _filterPatients() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredPatients = _allPatients;
      } else {
        _filteredPatients = _allPatients.where((patient) {
          return patient.fullName.toLowerCase().contains(query) ||
                 (patient.diagnosis?.toLowerCase().contains(query) ?? false);
        }).toList();
      }
    });
  }
  
  void _navigateToAddPatient() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const AddPatientScreen()),
    );
    setState(() {
      _patientsFuture = _loadPatients(); 
    });
  }

  void _navigateToPatientProfile(Patient patient) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => PatientProfileScreen(patient: patient)),
    );
  }

  // 🆕 (جديد) دالة لحذف المريض مع تأكيد
  void _deletePatient(Patient patient) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text('تأكيد الحذف'),
          content: Text('هل أنت متأكد من رغبتك في حذف ملف المريض: ${patient.fullName}؟\n\nسيتم حذف جميع تقييماته ومواعيده بشكل نهائي.'),
          actions: <Widget>[
            TextButton(
              child: const Text('إلغاء'),
              onPressed: () {
                Navigator.of(ctx).pop();
              },
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('حذف'),
              onPressed: () async {
                await DatabaseHelper.instance.deletePatient(patient.patientId!);
                if (mounted) {
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('تم حذف ملف: ${patient.fullName}')),
                  );
                }
                // تحديث القائمة
                setState(() {
                  _patientsFuture = _loadPatients();
                });
              },
            ),
          ],
        );
      },
    );
  }


  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📋 قائمة المرضى'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: _navigateToAddPatient,
            tooltip: 'إضافة مريض جديد',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'بحث سريع بالاسم أو التشخيص',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(25.0)),
                ),
              ),
            ),
          ),
          
          Expanded(
            child: FutureBuilder<List<Patient>>(
              future: _patientsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text('حدث خطأ: ${snapshot.error}'));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Text(
                      'لا يوجد مرضى حتى الآن. ابدأ بإضافة مريض جديد!',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  );
                }
                
                return ListView.builder(
                  itemCount: _filteredPatients.length,
                  itemBuilder: (context, index) {
                    final patient = _filteredPatients[index];
                    return PatientCard(
                      patient: patient,
                      onTap: () => _navigateToPatientProfile(patient),
                      // 🆕 (جديد) تمرير دالة الحذف
                      onDelete: () => _deletePatient(patient),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddPatient,
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ----------------------------------
// (✅ معدلة) بطاقة عرض المريض 
// ----------------------------------
class PatientCard extends StatelessWidget {
  final Patient patient;
  final VoidCallback onTap;
  final VoidCallback onDelete; // 🆕 (جديد)

  const PatientCard({
    super.key, 
    required this.patient, 
    required this.onTap,
    required this.onDelete, // 🆕 (جديد)
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).primaryColor,
          child: Text(
            patient.fullName.isNotEmpty ? patient.fullName[0].toUpperCase() : '?',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          patient.fullName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('التشخيص: ${patient.diagnosis ?? 'لا يوجد'}'),
            Text('العمر: ${patient.calculateAge()}'), 
          ],
        ),
        // 🆕 (تعديل) إضافة زر الحذف
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          onPressed: onDelete,
          tooltip: 'حذف ملف المريض',
        ),
      ),
    );
  }
}