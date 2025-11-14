import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

// استيراد النماذج
import '../models/ot_settings.dart';
import '../models/patient.dart'; 
// استيراد البيانات الثابتة (تأكد من وجود هذا الملف)
import 'static_data.dart'; 

const String databaseName = 'ot_toolbox.db';
const int databaseVersion = 6; 

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();
  static Database? _database;

  DatabaseHelper._privateConstructor();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, databaseName);

    return await openDatabase(
      path,
      version: databaseVersion,
      onConfigure: (db) async {
        // تفعيل الحذف التلقائي للعلاقات
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade, 
    );
  }

  Future _onCreate(Database db, int version) async {
     await db.execute('''
      CREATE TABLE OT_Settings (
        id INTEGER PRIMARY KEY,
        ot_name TEXT NOT NULL,
        clinic_logo_path TEXT,
        app_version TEXT,
        theme_mode TEXT DEFAULT 'system'
      )
    ''');
    await db.execute('''
      CREATE TABLE Patients (
        patient_id INTEGER PRIMARY KEY AUTOINCREMENT,
        full_name TEXT NOT NULL,
        diagnosis TEXT,
        dob TEXT, 
        gender TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE Assessments (
        assessment_id INTEGER PRIMARY KEY AUTOINCREMENT,
        patient_id INTEGER NOT NULL,
        assessment_type TEXT NOT NULL,
        status TEXT NOT NULL,
        date_created TEXT,
        date_completed TEXT,
        FOREIGN KEY (patient_id) REFERENCES Patients(patient_id)
          ON DELETE CASCADE 
      )
    ''');
    await db.execute('''
      CREATE TABLE Scheduled_Appointments (
        appointment_id INTEGER PRIMARY KEY AUTOINCREMENT,
        patient_id INTEGER NOT NULL,
        appointment_date TEXT NOT NULL,
        notes TEXT,
        FOREIGN KEY (patient_id) REFERENCES Patients(patient_id)
          ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE ROM_Results (
        result_id INTEGER PRIMARY KEY AUTOINCREMENT,
        assessment_id INTEGER NOT NULL,
        joint_name TEXT,
        motion_type TEXT,
        active_range REAL,
        passive_range REAL,
        pain_level TEXT,
        clinical_note TEXT, 
        FOREIGN KEY (assessment_id) REFERENCES Assessments(assessment_id)
          ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE Skills_Master (
        skill_id INTEGER PRIMARY KEY AUTOINCREMENT,
        skill_group TEXT NOT NULL,
        skill_description TEXT NOT NULL,
        min_age_months INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE Skills_Results (
        result_id INTEGER PRIMARY KEY AUTOINCREMENT,
        assessment_id INTEGER NOT NULL,
        skill_id INTEGER NOT NULL,
        score TEXT, 
        clinical_note TEXT, 
        FOREIGN KEY (assessment_id) REFERENCES Assessments(assessment_id)
          ON DELETE CASCADE,
        FOREIGN KEY (skill_id) REFERENCES Skills_Master(skill_id)
      )
    ''');
    await db.execute('''
      CREATE TABLE Grip_Assessment_Results (
        result_id INTEGER PRIMARY KEY AUTOINCREMENT,
        assessment_id INTEGER NOT NULL,
        hand TEXT NOT NULL,
        grasp_type TEXT,
        holding_ability TEXT,
        release_ability TEXT,
        coordination TEXT,
        atypical_signs TEXT,
        clinical_note TEXT,
        FOREIGN KEY (assessment_id) REFERENCES Assessments(assessment_id)
          ON DELETE CASCADE
      )
    ''');
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try { await db.execute("ALTER TABLE ROM_Results ADD COLUMN clinical_note TEXT"); } catch (_) {}
    }
    if (oldVersion < 3) {
      await db.execute("DROP TABLE IF EXISTS Skills_Results");
      await db.execute('''
        CREATE TABLE Skills_Results (
          result_id INTEGER PRIMARY KEY AUTOINCREMENT,
          assessment_id INTEGER NOT NULL,
          skill_id INTEGER NOT NULL,
          score TEXT, 
          clinical_note TEXT, 
          FOREIGN KEY (assessment_id) REFERENCES Assessments(assessment_id) ON DELETE CASCADE, 
          FOREIGN KEY (skill_id) REFERENCES Skills_Master(skill_id)
        )
      ''');
    }
    if (oldVersion < 4) {
      await db.execute("DROP TABLE IF EXISTS Grip_Assessment_Results");
      await db.execute('''
        CREATE TABLE Grip_Assessment_Results (
          result_id INTEGER PRIMARY KEY AUTOINCREMENT,
          assessment_id INTEGER NOT NULL,
          hand TEXT NOT NULL,
          grasp_type TEXT,
          holding_ability TEXT,
          release_ability TEXT,
          coordination TEXT,
          atypical_signs TEXT,
          clinical_note TEXT,
          FOREIGN KEY (assessment_id) REFERENCES Assessments(assessment_id) ON DELETE CASCADE
        )
      ''');
    }
    if (oldVersion < 6) {
      try { await db.execute("ALTER TABLE OT_Settings ADD COLUMN theme_mode TEXT DEFAULT 'system'"); } catch (_) {}
    }
  }

  // ==========================================
  //            وظائف OT_Settings
  // ==========================================
  
  Future<int> insertInitialSettings() async {
    final db = await instance.database;
    final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM OT_Settings'));
    if (count != null && count > 0) return 0;
    return await db.insert('OT_Settings', {
      'ot_name': 'أخصائي العلاج الوظيفي (افتراضي)',
      'app_version': '1.0.0',
      'theme_mode': 'system',
    });
  }

  Future<OtSettings?> getSettings() async {
    final db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query('OT_Settings', limit: 1);
    if (maps.isNotEmpty) return OtSettings.fromMap(maps.first);
    return null;
  }
  
  Future<int> updateSettings(OtSettings settings) async {
    final db = await instance.database;
    // حذف ID من البيانات لتجنب خطأ التحديث
    final data = settings.toMap();
    data.remove('id');

    if (settings.id != null) {
      return await db.update('OT_Settings', data, where: 'id = ?', whereArgs: [settings.id]);
    } else {
      return await db.update('OT_Settings', data, where: 'id = (SELECT min(id) FROM OT_Settings)');
    }
  }

  // ==========================================
  //            وظائف Patients
  // ==========================================

  Future<int> insertPatient(Patient patient) async {
    final db = await instance.database;
    return await db.insert('Patients', patient.toMap());
  }

  Future<List<Patient>> getPatients() async {
    final db = await instance.database;
    final maps = await db.query('Patients', orderBy: 'full_name ASC');
    return List.generate(maps.length, (i) => Patient.fromMap(maps[i]));
  }
  
  Future<Patient?> getPatient(int id) async {
    final db = await instance.database;
    final maps = await db.query('Patients', where: 'patient_id = ?', whereArgs: [id], limit: 1);
    if (maps.isNotEmpty) return Patient.fromMap(maps.first);
    return null;
  }

  Future<int> updatePatient(Patient patient) async {
    final db = await instance.database;
    final data = patient.toMap();
    data.remove('patient_id'); // إزالة المفتاح الرئيسي قبل التحديث
    return await db.update('Patients', data, where: 'patient_id = ?', whereArgs: [patient.patientId]);
  }

  Future<int> deletePatient(int patientId) async {
    final db = await instance.database;
    return await db.delete('Patients', where: 'patient_id = ?', whereArgs: [patientId]);
  }

  // ==========================================
  //      وظائف المواعيد (Appointments)
  // ==========================================

  Future<int> insertAppointment(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('Scheduled_Appointments', row);
  }

  Future<List<Map<String, dynamic>>> getAppointmentsForPatient(int patientId) async {
    final db = await instance.database;
    return await db.query('Scheduled_Appointments', where: 'patient_id = ?', whereArgs: [patientId], orderBy: 'appointment_date ASC');
  }

  Future<int> deleteAppointment(int appointmentId) async {
    final db = await instance.database;
    return await db.delete('Scheduled_Appointments', where: 'appointment_id = ?', whereArgs: [appointmentId]);
  }

  // ==========================================
  //      وظائف الرسوم البيانية (Charts)
  // ==========================================

  Future<List<Map<String, dynamic>>> getRomProgress({required int patientId, required String jointName, required String motionType}) async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT T2.date_created, T1.active_range
      FROM ROM_Results T1
      INNER JOIN Assessments T2 ON T1.assessment_id = T2.assessment_id
      WHERE T2.patient_id = ? AND T1.joint_name = ? AND T1.motion_type = ? AND T2.status = 'Completed'
      ORDER BY T2.date_created ASC
    ''', [patientId, jointName, motionType]);
  }

  // ==========================================
  //         وظائف لوحة التحكم (Dashboard)
  // ==========================================

  Future<int> getTotalPatientsCount() async {
    final db = await instance.database;
    return Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM Patients')) ?? 0;
  }

  Future<Patient?> getLastUpdatedPatient() async {
    final db = await instance.database;
    final maps = await db.rawQuery('''
      SELECT T1.*, T2.date_created FROM Patients T1
      INNER JOIN Assessments T2 ON T1.patient_id = T2.patient_id
      ORDER BY T2.date_created DESC LIMIT 1
    ''');
    if (maps.isNotEmpty) return Patient.fromMap(maps.first);
    final pMaps = await db.query('Patients', orderBy: 'patient_id DESC', limit: 1);
    if (pMaps.isNotEmpty) return Patient.fromMap(pMaps.first);
    return null;
  }
  
  Future<List<Map<String, dynamic>>> getScheduledAppointmentsToday() async {
    final db = await instance.database;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return await db.rawQuery('''
      SELECT T1.appointment_date, T2.full_name, T2.patient_id
      FROM Scheduled_Appointments T1
      INNER JOIN Patients T2 ON T1.patient_id = T2.patient_id
      WHERE date(T1.appointment_date) = ?
      ORDER BY T1.appointment_date ASC
    ''', [today]);
  }

  Future<List<Map<String, dynamic>>> getLastAssessments(int limit) async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT T1.assessment_id, T1.assessment_type, T1.status, T1.date_created, T2.full_name, T2.patient_id
      FROM Assessments T1
      INNER JOIN Patients T2 ON T1.patient_id = T2.patient_id
      ORDER BY T1.date_created DESC LIMIT ?
    ''', [limit]);
  }

  // ==========================================
  //         وظائف Skills
  // ==========================================
  
  Future<void> insertInitialSkills() async {
    final db = await instance.database;
    final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM Skills_Master'));
    if (count != null && count > 0) return; 
    
    // ✅ استخدام البيانات من ملف static_data.dart
    final Batch batch = db.batch();
    for (var skill in StaticData.initialSkills) {
      batch.insert('Skills_Master', skill);
    }
    await batch.commit();
  }
  
  // ✅ (تمت إعادتها) جلب المهارات حسب العمر
  Future<List<Map<String, dynamic>>> getSkillsByAge(int months) async {
    final db = await instance.database;
    return await db.query(
      'Skills_Master',
      where: 'min_age_months <= ?',
      whereArgs: [months],
      orderBy: 'skill_group ASC, min_age_months ASC',
    );
  }

  // حفظ Skills (جديد أو تحديث)
  Future<int> saveSkillsAssessment({
    required int patientId,
    required String status,
    required List<Map<String, dynamic>> results,
    int? existingAssessmentId,
  }) async {
    final db = await instance.database;
    final now = DateTime.now().toIso8601String();
    int assessmentId = 0;
    
    await db.transaction((txn) async {
      if (existingAssessmentId != null) {
        assessmentId = existingAssessmentId;
        await txn.update('Assessments', {
          'status': status,
          'date_completed': status == 'Completed' ? now : null,
        }, where: 'assessment_id = ?', whereArgs: [assessmentId]);
        await txn.delete('Skills_Results', where: 'assessment_id = ?', whereArgs: [assessmentId]);
      } else {
        assessmentId = await txn.insert('Assessments', {
          'patient_id': patientId,
          'assessment_type': 'Skills',
          'status': status,
          'date_created': now,
          'date_completed': status == 'Completed' ? now : null,
        });
      }

      final Batch batch = txn.batch();
      for (var result in results) {
        batch.insert('Skills_Results', {
          'assessment_id': assessmentId,
          'skill_id': result['skill_id'],
          'score': result['score'], 
          'clinical_note': result['clinical_note'],
        });
      }
      await batch.commit(noResult: true);
    });
    return assessmentId;
  }

  // حفظ ROM (جديد أو تحديث)
  Future<int> saveROMAssessment({
    required int patientId,
    required String status,
    required List<Map<String, dynamic>> results,
    int? existingAssessmentId,
  }) async {
    final db = await instance.database;
    final now = DateTime.now().toIso8601String();
    int assessmentId = 0;

    await db.transaction((txn) async {
      if (existingAssessmentId != null) {
        assessmentId = existingAssessmentId;
        await txn.update('Assessments', {
          'status': status,
          'date_completed': status == 'Completed' ? now : null,
        }, where: 'assessment_id = ?', whereArgs: [assessmentId]);
        await txn.delete('ROM_Results', where: 'assessment_id = ?', whereArgs: [assessmentId]);
      } else {
        assessmentId = await txn.insert('Assessments', {
          'patient_id': patientId,
          'assessment_type': 'ROM',
          'status': status,
          'date_created': now,
          'date_completed': status == 'Completed' ? now : null,
        });
      }

      final Batch batch = txn.batch();
      for (var result in results) {
        batch.insert('ROM_Results', {
          'assessment_id': assessmentId,
          'joint_name': result['joint_name'],
          'motion_type': result['motion_type'],
          'active_range': result['active_range'],
          'passive_range': result['passive_range'],
          'pain_level': result['pain_level'],
          'clinical_note': result['clinical_note'], 
        });
      }
      await batch.commit(noResult: true);
    });
    return assessmentId;
  }

  // حفظ Grip (جديد أو تحديث)
  Future<int> saveGripAssessment({
    required int patientId,
    required String status,
    required List<Map<String, dynamic>> results, 
    int? existingAssessmentId,
  }) async {
    final db = await instance.database;
    final now = DateTime.now().toIso8601String();
    int assessmentId = 0;

    await db.transaction((txn) async {
      if (existingAssessmentId != null) {
        assessmentId = existingAssessmentId;
        await txn.update('Assessments', {
          'status': status,
          'date_completed': status == 'Completed' ? now : null,
        }, where: 'assessment_id = ?', whereArgs: [assessmentId]);
        await txn.delete('Grip_Assessment_Results', where: 'assessment_id = ?', whereArgs: [assessmentId]);
      } else {
        assessmentId = await txn.insert('Assessments', {
          'patient_id': patientId,
          'assessment_type': 'Grip',
          'status': status,
          'date_created': now,
          'date_completed': status == 'Completed' ? now : null,
        });
      }

      final Batch batch = txn.batch();
      for (var handResult in results) {
        batch.insert('Grip_Assessment_Results', {
          'assessment_id': assessmentId,
          'hand': handResult['hand'],
          'grasp_type': handResult['grasp_type'],
          'holding_ability': handResult['holding_ability'],
          'release_ability': handResult['release_ability'],
          'coordination': handResult['coordination'],
          'atypical_signs': handResult['atypical_signs'],
          'clinical_note': handResult['clinical_note'],
        });
      }
      await batch.commit(noResult: true);
    });
    return assessmentId;
  }
  
  // --- التقارير ---
  Future<Map<String, dynamic>?> getAssessmentDetails(int assessmentId) async {
    final db = await instance.database;
    final maps = await db.query('Assessments', where: 'assessment_id = ?', whereArgs: [assessmentId], limit: 1);
    if (maps.isNotEmpty) return maps.first;
    return null;
  }

  Future<List<Map<String, dynamic>>> getROMResultsForReport(int assessmentId) async {
    final db = await instance.database;
    return await db.query('ROM_Results', where: 'assessment_id = ?', whereArgs: [assessmentId]);
  }

  Future<List<Map<String, dynamic>>> getGripResultsForReport(int assessmentId) async {
    final db = await instance.database;
    return await db.query('Grip_Assessment_Results', where: 'assessment_id = ?', whereArgs: [assessmentId]);
  }

  Future<List<Map<String, dynamic>>> getSkillsResultsForReport(int assessmentId) async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT 
        T1.score, 
        T1.clinical_note,
        T2.skill_group,
        T2.skill_description,
        T1.skill_id
      FROM Skills_Results T1
      INNER JOIN Skills_Master T2 ON T1.skill_id = T2.skill_id
      WHERE T1.assessment_id = ? 
      AND T1.score IS NOT NULL AND T1.score != 'يستطيع' 
      ORDER BY T2.skill_group ASC, T2.min_age_months ASC
    ''', [assessmentId]);
  }

  // ✅ دالة جلب المهارات للتعديل (شاملة الكل)
  Future<List<Map<String, dynamic>>> getAllSkillsResultsForEdit(int assessmentId) async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT 
        T1.score, 
        T1.clinical_note,
        T1.skill_id,
        T2.skill_group,
        T2.skill_description
      FROM Skills_Results T1
      INNER JOIN Skills_Master T2 ON T1.skill_id = T2.skill_id
      WHERE T1.assessment_id = ?
    ''', [assessmentId]);
  }

  Future<List<Map<String, dynamic>>> getAssessmentsForPatient(int patientId) async {
    final db = await instance.database;
    return await db.query('Assessments', where: 'patient_id = ?', whereArgs: [patientId], orderBy: 'date_created DESC');
  }

  Future<int> deleteAssessment(int assessmentId) async {
    final db = await instance.database;
    return await db.delete('Assessments', where: 'assessment_id = ?', whereArgs: [assessmentId]);
  }

  // --- الملخص ---
  Future<Map<String, int?>> getLatestAssessmentIds(int patientId) async {
    final db = await instance.database;
    Map<String, int?> assessmentIds = {'ROM': null, 'Grip': null, 'Skills': null};
    var rom = await db.query('Assessments', columns: ['assessment_id'], where: 'patient_id = ? AND assessment_type = ? AND status = ?', whereArgs: [patientId, 'ROM', 'Completed'], orderBy: 'date_created DESC', limit: 1);
    if (rom.isNotEmpty) assessmentIds['ROM'] = rom.first['assessment_id'] as int?;
    var grip = await db.query('Assessments', columns: ['assessment_id'], where: 'patient_id = ? AND assessment_type = ? AND status = ?', whereArgs: [patientId, 'Grip', 'Completed'], orderBy: 'date_created DESC', limit: 1);
    if (grip.isNotEmpty) assessmentIds['Grip'] = grip.first['assessment_id'] as int?;
    var skills = await db.query('Assessments', columns: ['assessment_id'], where: 'patient_id = ? AND assessment_type = ? AND status = ?', whereArgs: [patientId, 'Skills', 'Completed'], orderBy: 'date_created DESC', limit: 1);
    if (skills.isNotEmpty) assessmentIds['Skills'] = skills.first['assessment_id'] as int?;
    return assessmentIds;
  }
}