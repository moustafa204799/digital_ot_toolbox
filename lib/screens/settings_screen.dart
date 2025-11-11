import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/ot_settings.dart'; 

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _otNameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  OtSettings? _currentSettings;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  // جلب البيانات الحالية من قاعدة البيانات
  Future<void> _loadSettings() async {
    final settings = await DatabaseHelper.instance.getSettings();
    if (mounted) {
      setState(() {
        _currentSettings = settings;
        if (settings != null) {
          _otNameController.text = settings.otName;
        }
        _isLoading = false;
      });
    }
  }

  // حفظ التعديلات في قاعدة البيانات
  Future<void> _saveSettings() async {
    if (_formKey.currentState!.validate()) {
      final newSettings = OtSettings(
        id: 1, // نفترض ID=1
        otName: _otNameController.text,
        clinicLogoPath: _currentSettings?.clinicLogoPath, 
        appVersion: _currentSettings?.appVersion,
      );

      final result = await DatabaseHelper.instance.updateSettings(newSettings);
      
      // إظهار رسالة تأكيد بسيطة
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result > 0 ? 'تم حفظ الإعدادات بنجاح!' : 'فشل الحفظ')),
        );
      }
      // تحديث البيانات المعروضة
      _loadSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('👨‍⚕️ إعدادات الأخصائي والمعلومات'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const Text(
                      'إعدادات الملف الشخصي للتقرير (Branding)',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const Divider(),
                    // حقل اسم الأخصائي
                    TextFormField(
                      controller: _otNameController,
                      decoration: const InputDecoration(
                        labelText: 'الاسم الكامل للأخصائي',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'الرجاء إدخال اسم الأخصائي';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    // معلومات عن الشعار
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.palette),
                        title: const Text('شعار العيادة / التخصيص'),
                        subtitle: Text(_currentSettings?.clinicLogoPath ?? 'لم يتم اختيار شعار بعد'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          // TODO: شاشة اختيار وتحميل الشعار هنا
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('سيتم تطوير وظيفة رفع الشعار لاحقاً.')),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 30),
                    
                    // زر الحفظ
                    ElevatedButton.icon(
                      onPressed: _saveSettings,
                      icon: const Icon(Icons.save),
                      label: const Text('حفظ الإعدادات', style: TextStyle(fontSize: 18)),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                    ),
                    
                    const SizedBox(height: 40),
                    // معلومات التطبيق (About)
                    const Text(
                      'معلومات التطبيق',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.info_outline),
                      title: const Text('إصدار التطبيق'),
                      subtitle: Text(_currentSettings?.appVersion ?? 'غير متوفر'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
  
  @override
  void dispose() {
    _otNameController.dispose();
    super.dispose();
  }
}