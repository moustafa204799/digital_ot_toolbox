import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart'; // 🆕 تأكد من إضافة المكتبة لـ pubspec.yaml
import '../database/database_helper.dart';
import '../models/ot_settings.dart';
import '../main.dart'; // لاستدعاء themeNotifier

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _otNameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  OtSettings? _currentSettings;
  String? _logoPath;
  String _selectedTheme = 'system'; // الافتراضي
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await DatabaseHelper.instance.getSettings();
    if (mounted) {
      setState(() {
        _currentSettings = settings;
        if (settings != null) {
          _otNameController.text = settings.otName;
          _logoPath = settings.clinicLogoPath;
          _selectedTheme = settings.themeMode; // قراءة الثيم المحفوظ
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _pickLogo() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        final appDir = await getApplicationDocumentsDirectory();
        final String newPath = '${appDir.path}/clinic_logo_v2.png';
        await File(image.path).copy(newPath);
        setState(() { _logoPath = newPath; });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  Future<void> _saveSettings() async {
    if (_formKey.currentState!.validate()) {
      final newSettings = OtSettings(
        id: _currentSettings?.id,
        otName: _otNameController.text,
        clinicLogoPath: _logoPath,
        appVersion: _currentSettings?.appVersion ?? '1.0.0',
        themeMode: _selectedTheme, // 🆕 حفظ الثيم
      );

      final result = await DatabaseHelper.instance.updateSettings(newSettings);
      
      // 🆕 تحديث الثيم فوراً
      if (_selectedTheme == 'light') themeNotifier.value = ThemeMode.light;
      else if (_selectedTheme == 'dark') themeNotifier.value = ThemeMode.dark;
      else themeNotifier.value = ThemeMode.system;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result > 0 ? '✅ تم الحفظ وتحديث المظهر' : '❌ فشل الحفظ')),
        );
        setState(() { _currentSettings = newSettings; });
      }
    }
  }

  // دالة مساعدة لفتح الروابط
  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا يمكن فتح الرابط')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('⚙️ الإعدادات', style: TextStyle(fontSize: 20.sp))),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16.w),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    
                    // --- قسم البيانات الشخصية ---
                    _buildSectionTitle('بيانات الأخصائي'),
                    Card(
                      child: Padding(
                        padding: EdgeInsets.all(12.w),
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _otNameController,
                              decoration: const InputDecoration(
                                labelText: 'الاسم الكامل',
                                prefixIcon: Icon(Icons.person),
                                border: OutlineInputBorder(),
                              ),
                              validator: (val) => val!.isEmpty ? 'مطلوب' : null,
                            ),
                            SizedBox(height: 15.h),
                            Row(
                              children: [
                                GestureDetector(
                                  onTap: _pickLogo,
                                  child: CircleAvatar(
                                    radius: 30.r,
                                    backgroundColor: Colors.grey[300],
                                    backgroundImage: _logoPath != null && File(_logoPath!).existsSync()
                                        ? FileImage(File(_logoPath!))
                                        : null,
                                    child: _logoPath == null ? const Icon(Icons.add_a_photo) : null,
                                  ),
                                ),
                                SizedBox(width: 15.w),
                                const Expanded(child: Text('شعار العيادة')),
                                TextButton(onPressed: _pickLogo, child: const Text('تغيير')),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    SizedBox(height: 20.h),

                    // --- قسم المظهر ---
                    _buildSectionTitle('المظهر والتطبيق'),
                    Card(
                      child: Padding(
                        padding: EdgeInsets.all(12.w),
                        child: DropdownButtonFormField<String>(
                          value: _selectedTheme,
                          decoration: const InputDecoration(
                            labelText: 'نمط العرض (Theme)',
                            prefixIcon: Icon(Icons.brightness_6),
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'system', child: Text('⚙️ حسب النظام')),
                            DropdownMenuItem(value: 'light', child: Text('☀️ الوضع الفاتح')),
                            DropdownMenuItem(value: 'dark', child: Text('🌙 الوضع الداكن')),
                          ],
                          onChanged: (val) => setState(() { _selectedTheme = val!; }),
                        ),
                      ),
                    ),

                    SizedBox(height: 20.h),
                    
                    ElevatedButton.icon(
                      onPressed: _saveSettings,
                      icon: const Icon(Icons.save),
                      label: const Text('حفظ التغييرات'),
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                      ),
                    ),

                    SizedBox(height: 30.h),
                    const Divider(),

                    // --- قسم عن التطبيق ---
                    _buildSectionTitle('عن التطبيق'),
                    Card(
                      child: Padding(
                        padding: EdgeInsets.all(16.w),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Digital OT Toolbox', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold)),
                            SizedBox(height: 8.h),
                            Text(
                              'تطبيق شامل لأخصائيي العلاج الوظيفي لتقييم المرضى وتتبع تقدمهم وإصدار التقارير.\nالإصدار: ${_currentSettings?.appVersion ?? '1.0.0'}',
                              style: TextStyle(fontSize: 14.sp, height: 1.5),
                            ),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: 20.h),

                    // --- قسم التواصل ---
                    _buildSectionTitle('تواصل معنا'),
                    Card(
                      child: Column(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.email, color: Colors.blue),
                            title: const Text('البريد الإلكتروني'),
                            subtitle: const Text('support@ot-toolbox.com'),
                            onTap: () => _launchURL('mailto:support@ot-toolbox.com'),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: const Icon(Icons.language, color: Colors.purple),
                            title: const Text('الموقع الإلكتروني'),
                            subtitle: const Text('www.ot-toolbox.com'),
                            onTap: () => _launchURL('https://www.ot-toolbox.com'),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 40.h),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h, right: 4.w),
      child: Text(title, style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, color: Colors.grey)),
    );
  }
  
  @override
  void dispose() {
    _otNameController.dispose();
    super.dispose();
  }
}