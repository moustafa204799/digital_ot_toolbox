class Patient {
  final int? patientId; // PK
  final String fullName;
  final String? diagnosis;
  final String dob; // Date of Birth - سيتم حفظه كسلسلة نصية (YYYY-MM-DD)
  final String? gender;

  Patient({
    this.patientId,
    required this.fullName,
    this.diagnosis,
    required this.dob,
    this.gender,
  });

  // 🆕 دالة جديدة: لحساب العمر بالسنوات
  String calculateAge() {
    try {
      final today = DateTime.now();
      final birthDate = DateTime.parse(dob);
      
      int years = today.year - birthDate.year;
      int months = today.month - birthDate.month;
      
      if (today.day < birthDate.day) {
        months--;
      }
      if (months < 0) {
        years--;
        months += 12;
      }
      
      // لتكون النتيجة احترافية ومفيدة للعلاج الوظيفي (X سنة Y شهر)
      return '$years سنة و $months أشهر'; 
      
    } catch (e) {
      return 'العمر غير معروف';
    }
  }

  // لتحويل الخريطة (Map) القادمة من قاعدة البيانات إلى كائن (Object)
  factory Patient.fromMap(Map<String, dynamic> map) {
    return Patient(
      patientId: map['patient_id'] as int?,
      fullName: map['full_name'] as String,
      diagnosis: map['diagnosis'] as String?,
      dob: map['dob'] as String,
      gender: map['gender'] as String?,
    );
  }

  // لتحويل الكائن (Object) إلى خريطة (Map) لحفظه في قاعدة البيانات
  Map<String, dynamic> toMap() {
    return {
      'patient_id': patientId,
      'full_name': fullName,
      'diagnosis': diagnosis,
      'dob': dob,
      'gender': gender,
    };
  }
}