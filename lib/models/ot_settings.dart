class OtSettings {
  final int? id; // PK
  final String otName;
  final String? clinicLogoPath;
  final String? appVersion;

  OtSettings({
    this.id,
    required this.otName,
    this.clinicLogoPath,
    this.appVersion,
  });

  // لتحويل الخريطة (Map) القادمة من قاعدة البيانات إلى كائن (Object)
  factory OtSettings.fromMap(Map<String, dynamic> map) {
    return OtSettings(
      id: map['id'] as int?,
      otName: map['ot_name'] as String,
      clinicLogoPath: map['clinic_logo_path'] as String?,
      appVersion: map['app_version'] as String?,
    );
  }

  // لتحويل الكائن (Object) إلى خريطة (Map) لحفظه في قاعدة البيانات
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ot_name': otName,
      'clinic_logo_path': clinicLogoPath,
      'app_version': appVersion,
    };
  }
}