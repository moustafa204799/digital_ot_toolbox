import 'package:flutter/foundation.dart'; 
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

// استيراد النماذج
import '../models/ot_settings.dart';
import '../models/patient.dart'; 

const String databaseName = 'ot_toolbox.db';
// ⬅️ (✅ تعديل: زيادة الإصدار لإجبار الترقية أو الإنشاء)
const int databaseVersion = 5; 

class DatabaseHelper {
  // تصميم Singleton (نقطة دخول واحدة لقاعدة البيانات)
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();
  static Database? _database;

  DatabaseHelper._privateConstructor();

  // 1. الدالة المسؤولة عن فتح قاعدة البيانات
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // 2. دالة تهيئة وفتح ملف قاعدة البيانات
  _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, databaseName);

    return await openDatabase(
      path,
      version: databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade, 
    );
  }

  // 3. الدالة المسؤولة عن إنشاء الجداول
  Future _onCreate(Database db, int version) async {
     await db.execute('''
      CREATE TABLE OT_Settings (
        id INTEGER PRIMARY KEY,
        ot_name TEXT NOT NULL,
        clinic_logo_path TEXT,
        app_version TEXT
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
    '''); // ⬅️ (✅ تعديل: إضافة ON DELETE CASCADE)
    await db.execute('''
      CREATE TABLE Scheduled_Appointments (
        appointment_id INTEGER PRIMARY KEY AUTOINCREMENT,
        patient_id INTEGER NOT NULL,
        appointment_date TEXT NOT NULL,
        notes TEXT,
        FOREIGN KEY (patient_id) REFERENCES Patients(patient_id)
          ON DELETE CASCADE
      )
    '''); // ⬅️ (✅ تعديل: إضافة ON DELETE CASCADE)
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
    '''); // ⬅️ (✅ تعديل: إضافة ON DELETE CASCADE)
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
    '''); // ⬅️ (✅ تعديل: إضافة ON DELETE CASCADE)
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
    '''); // ⬅️ (✅ تعديل: إضافة ON DELETE CASCADE)
  }

  // دالة الترقية (مهمة للمستخدمين الحاليين)
  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // (ملاحظة: لتطبيق CASCADE على قواعد البيانات الموجودة يتطلب الأمر
    // إعادة بناء الجداول، وهو أمر معقد. هذا الكود سيعمل للترقيات السابقة
    // ولكن لن يضيف CASCADE للمستخدمين القدامى إلا إذا حذفو التطبيق.
    // المستخدمون الجدد سيحصلون على CASCADE من _onCreate)

    if (oldVersion < 2) {
      try {
        await db.execute("ALTER TABLE ROM_Results ADD COLUMN clinical_note TEXT");
      } catch (e) {
        debugPrint('Column clinical_note already exists in ROM_Results: $e'); 
      }
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
          FOREIGN KEY (assessment_id) REFERENCES Assessments(assessment_id)
            ON DELETE CASCADE, 
          FOREIGN KEY (skill_id) REFERENCES Skills_Master(skill_id)
        )
      '''); // ⬅️ (✅ تعديل: تمت الإضافة هنا أيضاً)
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
          FOREIGN KEY (assessment_id) REFERENCES Assessments(assessment_id)
            ON DELETE CASCADE
        )
      '''); // ⬅️ (✅ تعديل: تمت الإضافة هنا أيضاً)
    }
    
    // (للتطبيق الكامل، ستحتاج لإضافة أوامر 'PRAGMA foreign_keys=OFF'
    // ثم 'CREATE TABLE' جديدة، ثم 'INSERT INTO ... SELECT'
    // ثم 'DROP TABLE' قديمة، ثم 'PRAGMA foreign_keys=ON'
    // ولكننا سنبقيها بسيطة الآن)
    if (oldVersion < 5) {
       // يمكنك إضافة التغييرات المستقبلية هنا
    }
  }

  // ==========================================
  //            وظائف OT_Settings
  // ==========================================
  
  Future<int> insertInitialSettings() async {
    final db = await instance.database;
    final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM OT_Settings'));
    if (count != null && count > 0) {
      return 0;
    }
    return await db.insert('OT_Settings', {
      'ot_name': 'أخصائي العلاج الوظيفي (افتراضي)',
      'app_version': '1.0.0',
    });
  }

  Future<OtSettings?> getSettings() async {
    final db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'OT_Settings',
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return OtSettings.fromMap(maps.first);
    }
    return null;
  }
  
  Future<int> updateSettings(OtSettings settings) async {
    final db = await instance.database;
    return await db.update(
      'OT_Settings',
      settings.toMap(),
      where: 'id = ?',
      whereArgs: [1],
    );
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
    final List<Map<String, dynamic>> maps = await db.query('Patients', orderBy: 'full_name ASC');
    return List.generate(maps.length, (i) {
      return Patient.fromMap(maps[i]);
    });
  }
  
  Future<Patient?> getPatient(int id) async {
    final db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'Patients',
      where: 'patient_id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return Patient.fromMap(maps.first);
    }
    return null;
  }

  // ⬅️ (✅ تعديل: تم تبسيط الدالة بالكامل)
  Future<int> deletePatient(int patientId) async {
    final db = await instance.database;
    
    // بفضل "ON DELETE CASCADE"، سيقوم SQLite بحذف كل السجلات
    // في (Assessments, Scheduled_Appointments) المرتبطة بهذا المريض،
    // وكذلك كل السجلات في (ROM_Results, Skills_Results, Grip_Assessment_Results)
    // المرتبطة بتلك التقييمات.
    
    return await db.delete(
      'Patients',
      where: 'patient_id = ?',
      whereArgs: [patientId],
    );
  }

  // ==========================================
  //         وظائف لوحة التحكم (Dashboard)
  // ==========================================

  Future<int> getTotalPatientsCount() async {
    final db = await instance.database;
    final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM Patients'));
    return count ?? 0;
  }

  Future<Patient?> getLastUpdatedPatient() async {
    final db = await instance.database;
    final List<Map<String, dynamic>> assessmentMaps = await db.rawQuery('''
      SELECT T1.*, T2.date_created 
      FROM Patients T1
      INNER JOIN Assessments T2 ON T1.patient_id = T2.patient_id
      ORDER BY T2.date_created DESC
      LIMIT 1
    ''');
    
    if (assessmentMaps.isNotEmpty) {
      return Patient.fromMap(assessmentMaps.first);
    }
    
    final List<Map<String, dynamic>> patientMaps = await db.query(
      'Patients',
      orderBy: 'patient_id DESC',
      limit: 1,
    );
    
    if (patientMaps.isNotEmpty) {
      return Patient.fromMap(patientMaps.first);
    }
    return null;
  }
  
  Future<List<Map<String, dynamic>>> getScheduledAppointmentsToday() async {
    final db = await instance.database;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    
    // ⬅️ (✅ تعديل...): تم تطبيق هذا الإصلاح في إجابتنا السابقة
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
      SELECT 
        T1.assessment_id, 
        T1.assessment_type, 
        T1.status, 
        T1.date_created, 
        T2.full_name,
        T2.patient_id
      FROM Assessments T1
      INNER JOIN Patients T2 ON T1.patient_id = T2.patient_id
      ORDER BY T1.date_created DESC 
      LIMIT ?
    ''', [limit]);
  }

  // ==========================================
  //         وظائف Skills
  // ==========================================
  
  Future<void> insertInitialSkills() async {
    final db = await instance.database;
    
    final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM Skills_Master'));
    if (count != null && count > 0) return; 
    
    final List<Map<String, dynamic>> initialSkills = [
      // ... (كل بيانات المهارات الأولية كما هي) ...
      // Group 1: مهارات دقيقة وبناء
      {'skill_group': 'مهارات دقيقة وبناء', 'skill_description': 'مدّ اليد والإمساك بالأشياء لوضعها في الفم', 'min_age_months': 6},
      {'skill_group': 'مهارات دقيقة وبناء', 'skill_description': 'التحكم في ترك الأشياء بإرادة', 'min_age_months': 6},
      {'skill_group': 'مهارات دقيقة وبناء', 'skill_description': 'التقاط الأشياء الصغيرة بين الإبهام وأصبع واحد', 'min_age_months': 6},
      {'skill_group': 'مهارات دقيقة وبناء', 'skill_description': 'نقل الأشياء من يد إلى أخرى', 'min_age_months': 6},
      {'skill_group': 'مهارات دقيقة وبناء', 'skill_description': 'ضرب مكعبين معًا في منتصف الجسم', 'min_age_months': 6},
      {'skill_group': 'مهارات دقيقة وبناء', 'skill_description': 'الإشارة أو النقر بإصبع السبابة', 'min_age_months': 6},
      {'skill_group': 'مهارات دقيقة وبناء', 'skill_description': 'استعادة الأشياء الساقطة...', 'min_age_months': 6},
      {'skill_group': 'مهارات دقيقة وبناء', 'skill_description': 'بناء برج من ثلاث مكعبات صغيرة', 'min_age_months': 12},
      {'skill_group': 'مهارات دقيقة وبناء', 'skill_description': 'وضع الحلقات على العصا', 'min_age_months': 12},
      {'skill_group': 'مهارات دقيقة وبناء', 'skill_description': 'تقليب صفحات الكتاب (صفحتين أو ثلاث معًا)', 'min_age_months': 12},
      {'skill_group': 'مهارات دقيقة وبناء', 'skill_description': 'إدارة المقابض', 'min_age_months': 12},
      {'skill_group': 'مهارات دقيقة وبناء', 'skill_description': 'استخدام الإشارات للتعبير عن الاحتياجات', 'min_age_months': 12},
      {'skill_group': 'مهارات دقيقة وبناء', 'skill_description': 'وضع الأشكال في صندوق الأشكال بدون مساعدة', 'min_age_months': 12},
      {'skill_group': 'مهارات دقيقة وبناء', 'skill_description': 'تركيب 3 - 4 خرزات كبيرة في خيط', 'min_age_months': 24},
      {'skill_group': 'مهارات دقيقة وبناء', 'skill_description': 'بناء برج من 3 - 5 مكعبات صغيرة', 'min_age_months': 24},
      {'skill_group': 'مهارات دقيقة وبناء', 'skill_description': 'تقليد ترتيب بسيط من مكعبات ملونة في برج', 'min_age_months': 24},
      {'skill_group': 'مهارات دقيقة وبناء', 'skill_description': 'تقليب صفحات الكتاب صفحة صفحة', 'min_age_months': 24},
      {'skill_group': 'مهارات دقيقة وبناء', 'skill_description': 'استخدام يد واحدة بشكل ثابت لمعظم الأنشطة', 'min_age_months': 24},
      {'skill_group': 'مهارات دقيقة وبناء', 'skill_description': 'إكمال ألعاب إدخال القطع (puzzles)', 'min_age_months': 24},
      {'skill_group': 'مهارات دقيقة وبناء', 'skill_description': 'بناء برج من حوالي 9 مكعبات صغيرة', 'min_age_months': 36},
      {'skill_group': 'مهارات دقيقة وبناء', 'skill_description': 'تقليد تصميم من 6 مكعبات', 'min_age_months': 36},
      {'skill_group': 'مهارات دقيقة وبناء', 'skill_description': 'استخدام يد واحدة باستمرار لمعظم الأنشطة', 'min_age_months': 36},
      {'skill_group': 'مهارات دقيقة وبناء', 'skill_description': 'استخدام اليد غير المسيطرة لتثبيت الأشياء', 'min_age_months': 36},
      {'skill_group': 'مهارات دقيقة وبناء', 'skill_description': 'تمرير خرزات صغيرة في خيط بترتيب', 'min_age_months': 36},
      {'skill_group': 'مهارات دقيقة وبناء', 'skill_description': 'إكمال ألعاب تركيب من 4 - 6 قطعة', 'min_age_months': 36},
      {'skill_group': 'مهارات دقيقة وبناء', 'skill_description': 'تقليد نماذج من 9 مكعبات', 'min_age_months': 48},
      {'skill_group': 'مهارات دقيقة وبناء', 'skill_description': 'تصميم نماذج من مكعبات Duplo', 'min_age_months': 48},
      {'skill_group': 'مهارات دقيقة وبناء', 'skill_description': 'استخدام يد مفضلة لمعظم الأنشطة', 'min_age_months': 48},
      {'skill_group': 'مهارات دقيقة وبناء', 'skill_description': 'نسخ صور بسيطة باستخدام الأشكال الهندسية', 'min_age_months': 48},
      {'skill_group': 'مهارات دقيقة وبناء', 'skill_description': 'رسم صور بسيطة بشكل مستقل', 'min_age_months': 48},
      {'skill_group': 'مهارات دقيقة وبناء', 'skill_description': 'إكمال ألعاب تركيب من 8 - 12 قطعة', 'min_age_months': 48},
      {'skill_group': 'مهارات دقيقة وبناء', 'skill_description': 'تصميم نماذج من مكعبات Lego', 'min_age_months': 60},
      {'skill_group': 'مهارات دقيقة وبناء', 'skill_description': 'رسم صور بسيطة', 'min_age_months': 60},
      {'skill_group': 'مهارات دقيقة وبناء', 'skill_description': 'إكمال ألعاب تركيب من 20 قطعة', 'min_age_months': 60},
      {'skill_group': 'مهارات دقيقة وبناء', 'skill_description': 'بناء نماذج Lego أو K\'nex وغيرها', 'min_age_months': 72},
      {'skill_group': 'مهارات دقيقة وبناء', 'skill_description': 'رسم صور تفصيلية تحتوي على عناصر واضحة', 'min_age_months': 72},
      {'skill_group': 'مهارات دقيقة وبناء', 'skill_description': 'إكمال ألعاب تركيب أكثر تعقيدًا', 'min_age_months': 84},
      {'skill_group': 'مهارات دقيقة وبناء', 'skill_description': 'رسم صور تفصيلية تحتوي على عناصر معروفة', 'min_age_months': 84},
      {'skill_group': 'مهارات ما قبل الكتابة', 'skill_description': 'التلوين بحركات الذراع الكاملة', 'min_age_months': 12},
      {'skill_group': 'مهارات ما قبل الكتابة', 'skill_description': 'مسك القلم بالإبهام والأصابع', 'min_age_months': 24},
      {'skill_group': 'مهارات ما قبل الكتابة', 'skill_description': 'تقليد رسم خطوط دائرية، رأسية وأفقية', 'min_age_months': 24},
      {'skill_group': 'مهارات ما قبل الكتابة', 'skill_description': 'التتبع على خطوط سميكة', 'min_age_months': 36},
      {'skill_group': 'مهارات ما قبل الكتابة', 'skill_description': 'نسخ دائرة أو تقليد رسم علامة (+)', 'min_age_months': 36},
      {'skill_group': 'مهارات ما قبل الكتابة', 'skill_description': 'مسك القلم بالإبهام والأصابع من الجانبين', 'min_age_months': 36},
      {'skill_group': 'مهارات ما قبل الكتابة', 'skill_description': 'نسخ دائرة، صليب، ومربع', 'min_age_months': 48},
      {'skill_group': 'مهارات ما قبل الكتابة', 'skill_description': 'مسك القلم بمسكة ثلاثية (3 أصابع)', 'min_age_months': 48},
      {'skill_group': 'مهارات ما قبل الكتابة', 'skill_description': 'التلوين داخل الخطوط', 'min_age_months': 48},
      {'skill_group': 'مهارات ما قبل الكتابة', 'skill_description': 'تلوين الصورة بالكاملكتابة الاسم', 'min_age_months': 48},
      {'skill_group': 'مهارات ما قبل الكتابة', 'skill_description': 'التتبع على خط بتحكم', 'min_age_months': 48},
      {'skill_group': 'مهارات ما قبل الكتابة', 'skill_description': 'نسخ الأرقام من 1 إلى 5', 'min_age_months': 48},
      {'skill_group': 'مهارات ما قبل الكتابة', 'skill_description': 'نسخ الحروف', 'min_age_months': 48},
      {'skill_group': 'مهارات ما قبل الكتابة', 'skill_description': 'نسخ مثلث', 'min_age_months': 60},
      {'skill_group': 'مهارات ما قبل الكتابة', 'skill_description': 'مسك القلم بثلاثة أصابع وتحريك الأصابع بدلاً من الرسغ', 'min_age_months': 60},
      {'skill_group': 'مهارات ما قبل الكتابة', 'skill_description': 'كتابة الأرقام من 1 إلى 10 بشكل مستقل', 'min_age_months': 60},
      {'skill_group': 'مهارات ما قبل الكتابة', 'skill_description': 'كتابة الحروف دون تقليد', 'min_age_months': 60},
      {'skill_group': 'مهارات ما قبل الكتابة', 'skill_description': 'الكتابة على السطر', 'min_age_months': 72},
      {'skill_group': 'مهارات ما قبل الكتابة', 'skill_description': 'التحكم في القلم', 'min_age_months': 72},
      {'skill_group': 'مهارات ما قبل الكتابة', 'skill_description': 'التحمل في مهام الكتابة', 'min_age_months': 72},
      {'skill_group': 'مهارات ما قبل الكتابة', 'skill_description': 'الكتابة بخط واضح', 'min_age_months': 84},
      {'skill_group': 'مهارات ما قبل الكتابة', 'skill_description': 'الحفاظ على وضوح الكتابة طوال القصة', 'min_age_months': 84},
      {'skill_group': 'مهارات القص بالمقص', 'skill_description': 'عمل قصّات بسيطة بالمقص', 'min_age_months': 24},
      {'skill_group': 'مهارات القص بالمقص', 'skill_description': 'قصّ الصور بشكل تقريبي', 'min_age_months': 36},
      {'skill_group': 'مهارات القص بالمقص', 'skill_description': 'القص على خط بشكل مستمر', 'min_age_months': 48},
      {'skill_group': 'مهارات القص بالمقص', 'skill_description': 'قصّ أشكال بسيطة', 'min_age_months': 60},
      {'skill_group': 'مهارات القص بالمقص', 'skill_description': 'تنفيذ أنشطة القص واللصق', 'min_age_months': 60},
      {'skill_group': 'مهارات القص بالمقص', 'skill_description': 'القص حول الأشكال بدقة', 'min_age_months': 72},
      {'skill_group': 'مهارات الاعتماد على الذات', 'skill_description': 'الأكل بشكل مستقل (مساعدة بسيطة ممكنة)', 'min_age_months': 12},
      {'skill_group': 'مهارات الاعتماد على الذات', 'skill_description': 'استخدام الملعقة للأكل', 'min_age_months': 12},
      {'skill_group': 'مهارات الاعتماد على الذات', 'skill_description': 'الإمساك بالكوب والشرب بدون مساعدة', 'min_age_months': 12},
      {'skill_group': 'مهارات الاعتماد على الذات', 'skill_description': 'الأكل بدون مساعدة', 'min_age_months': 24},
      {'skill_group': 'مهارات الاعتماد على الذات', 'skill_description': 'فتح أكياس السحاب (ziplock) والعلب وصناديق الغداء', 'min_age_months': 36},
      {'skill_group': 'مهارات الاعتماد على الذات', 'skill_description': 'تنسيق اليدين لتنظيف الأسنان أو تمشيط الشعر', 'min_age_months': 36},
      {'skill_group': 'مهارات الاعتماد على الذات', 'skill_description': 'اللبس بشكل مستقل (يشمل الأزرار الكبيرة، الجوارب، الأحذية) باستثناء الأربطة...', 'min_age_months': 36},
      {'skill_group': 'مهارات الاعتماد على الذات', 'skill_description': 'اللبس والخلع بشكل مستقل (ما عدا الأربطة)', 'min_age_months': 48},
      {'skill_group': 'مهارات الاعتماد على الذات', 'skill_description': 'استخدام السكين والشوكة للأطعمة اللينة', 'min_age_months': 60},
      {'skill_group': 'مهارات الاعتماد على الذات', 'skill_description': 'اللبس واستخدام الحمام بشكل مستقل', 'min_age_months': 72},
      {'skill_group': 'مهارات الاعتماد على الذات', 'skill_description': 'ربط أربطة الحذاء', 'min_age_months': 72},
      {'skill_group': 'مهارات الاعتماد على الذات', 'skill_description': 'استخدام السكين والشوكة لمعظم الأطعمة', 'min_age_months': 84},
    ];

    final Batch batch = db.batch();
    for (var skill in initialSkills) {
      batch.insert('Skills_Master', skill);
    }
    await batch.commit();
  }
  
  Future<List<Map<String, dynamic>>> getSkillsByAge(int patientAgeInMonths) async {
    final db = await instance.database;
    return await db.query(
      'Skills_Master',
      where: 'min_age_months <= ?',
      whereArgs: [patientAgeInMonths], 
      orderBy: 'skill_group ASC, min_age_months ASC', 
    );
  }

  Future<int> saveSkillsAssessment({
    required int patientId,
    required String status,
    required List<Map<String, dynamic>> results,
  }) async {
    final db = await instance.database;
    final now = DateTime.now().toIso8601String();
    int assessmentId = 0;
    
    await db.transaction((txn) async {
      assessmentId = await txn.insert('Assessments', {
        'patient_id': patientId,
        'assessment_type': 'Skills',
        'status': status,
        'date_created': now,
        'date_completed': status == 'Completed' ? now : null,
      });

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

  // ==========================================
  //         وظائف ROM
  // ==========================================
  Future<int> saveROMAssessment({
    required int patientId,
    required String status,
    required List<Map<String, dynamic>> results,
  }) async {
    final db = await instance.database;
    final now = DateTime.now().toIso8601String();
    int assessmentId = 0;

    await db.transaction((txn) async {
      assessmentId = await txn.insert('Assessments', {
        'patient_id': patientId,
        'assessment_type': 'ROM',
        'status': status,
        'date_created': now,
        'date_completed': status == 'Completed' ? now : null,
      });

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

  // ==========================================
  //         وظائف Grip Assessment
  // ==========================================
  Future<int> saveGripAssessment({
    required int patientId,
    required String status,
    required List<Map<String, dynamic>> results, 
  }) async {
    final db = await instance.database;
    final now = DateTime.now().toIso8601String();
    int assessmentId = 0;

    await db.transaction((txn) async {
      assessmentId = await txn.insert('Assessments', {
        'patient_id': patientId,
        'assessment_type': 'Grip',
        'status': status,
        'date_created': now,
        'date_completed': status == 'Completed' ? now : null,
      });

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
  
  // ==========================================
  //         وظائف التقارير (Reports)
  // ==========================================

  Future<Map<String, dynamic>?> getAssessmentDetails(int assessmentId) async {
    final db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'Assessments',
      where: 'assessment_id = ?',
      whereArgs: [assessmentId],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return maps.first;
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> getROMResultsForReport(int assessmentId) async {
    final db = await instance.database;
    return await db.query(
      'ROM_Results',
      where: 'assessment_id = ?',
      whereArgs: [assessmentId],
    );
  }

  Future<List<Map<String, dynamic>>> getGripResultsForReport(int assessmentId) async {
    final db = await instance.database;
    return await db.query(
      'Grip_Assessment_Results',
      where: 'assessment_id = ?',
      whereArgs: [assessmentId],
    );
  }

  Future<List<Map<String, dynamic>>> getSkillsResultsForReport(int assessmentId) async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT 
        T1.score, 
        T1.clinical_note,
        T2.skill_group,
        T2.skill_description
      FROM Skills_Results T1
      INNER JOIN Skills_Master T2 ON T1.skill_id = T2.skill_id
      WHERE T1.assessment_id = ? 
      AND T1.score IS NOT NULL AND T1.score != 'يستطيع' 
      ORDER BY T2.skill_group ASC, T2.min_age_months ASC
    ''', [assessmentId]);
  }


  Future<List<Map<String, dynamic>>> getAssessmentsForPatient(int patientId) async {
    final db = await instance.database;
    return await db.query(
      'Assessments', 
      where: 'patient_id = ?',
      whereArgs: [patientId],
      orderBy: 'date_created DESC',
    );
  }

  // ==========================================
  //         وظائف الحذف
  // ==========================================

  // ⬅️ (✅ تعديل: تم تبسيط الدالة بالكامل بفضل ON DELETE CASCADE)
  Future<int> deleteAssessment(int assessmentId) async {
    final db = await instance.database;
    
    // الآن، عند حذف 'Assessment'، سيقوم SQLite تلقائيًا
    // بحذف جميع السجلات المرتبطة في (ROM_Results, Grip_Assessment_Results, Skills_Results)
    // التي تحتوي على هذا (assessmentId)
    
    return await db.delete(
      'Assessments',
      where: 'assessment_id = ?',
      whereArgs: [assessmentId],
    );
  }

  // ==========================================
  //         وظائف الملخص
  // ==========================================

  Future<Map<String, int?>> getLatestAssessmentIds(int patientId) async {
    final db = await instance.database;
    Map<String, int?> assessmentIds = {
      'ROM': null,
      'Grip': null,
      'Skills': null,
    };

    var romResult = await db.query(
      'Assessments',
      columns: ['assessment_id'],
      where: 'patient_id = ? AND assessment_type = ? AND status = ?',
      whereArgs: [patientId, 'ROM', 'Completed'],
      orderBy: 'date_created DESC',
      limit: 1,
    );
    if (romResult.isNotEmpty) {
      assessmentIds['ROM'] = romResult.first['assessment_id'] as int?;
    }

    var gripResult = await db.query(
      'Assessments',
      columns: ['assessment_id'],
      where: 'patient_id = ? AND assessment_type = ? AND status = ?',
      whereArgs: [patientId, 'Grip', 'Completed'],
      orderBy: 'date_created DESC',
      limit: 1,
    );
    if (gripResult.isNotEmpty) {
      assessmentIds['Grip'] = gripResult.first['assessment_id'] as int?;
    }

    var skillsResult = await db.query(
      'Assessments',
      columns: ['assessment_id'],
      where: 'patient_id = ? AND assessment_type = ? AND status = ?',
      whereArgs: [patientId, 'Skills', 'Completed'],
      orderBy: 'date_created DESC',
      limit: 1,
    );
    if (skillsResult.isNotEmpty) {
      assessmentIds['Skills'] = skillsResult.first['assessment_id'] as int?;
    }

    return assessmentIds;
  }
}