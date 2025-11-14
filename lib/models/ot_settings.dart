class OtSettings {
  final int? id;
  final String otName;
  final String? clinicLogoPath;
  final String? appVersion;
  final String themeMode; // 🆕 حقل جديد: 'system', 'light', 'dark'

  OtSettings({
    this.id, 
    required this.otName, 
    this.clinicLogoPath, 
    this.appVersion,
    this.themeMode = 'system', // القيمة الافتراضية
  });

  factory OtSettings.fromMap(Map<String, dynamic> map) {
    return OtSettings(
      id: map['id'],
      otName: map['ot_name'],
      clinicLogoPath: map['clinic_logo_path'],
      appVersion: map['app_version'],
      themeMode: map['theme_mode'] ?? 'system', // 🆕 قراءة الثيم
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ot_name': otName,
      'clinic_logo_path': clinicLogoPath,
      'app_version': appVersion,
      'theme_mode': themeMode, // 🆕 حفظ الثيم
    };
  }

  OtSettings copyWith({
    String? otName,
    String? clinicLogoPath,
    String? appVersion,
    String? themeMode,
  }) {
    return OtSettings(
      id: id,
      otName: otName ?? this.otName,
      clinicLogoPath: clinicLogoPath ?? this.clinicLogoPath,
      appVersion: appVersion ?? this.appVersion,
      themeMode: themeMode ?? this.themeMode,
    );
  }
}