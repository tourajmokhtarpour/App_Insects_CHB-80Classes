import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

// ==================== مدل ذخیره‌سازی ====================
class ProcessedImage {
  final int? id;
  final String imagePath;
  final String pestName;
  final String commonName;
  final double confidence;
  final String jsonData;
  final DateTime processedAt;
  final bool sentViaEmail;
  final DateTime? sentAt;

  ProcessedImage({
    this.id,
    required this.imagePath,
    required this.pestName,
    required this.commonName,
    required this.confidence,
    required this.jsonData,
    required this.processedAt,
    this.sentViaEmail = false,
    this.sentAt,
  });

  // تبدیل به Map برای ذخیره‌سازی
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'imagePath': imagePath,
      'pestName': pestName,
      'commonName': commonName,
      'confidence': confidence,
      'jsonData': jsonData,
      'processedAt': processedAt.toIso8601String(),
      'sentViaEmail': sentViaEmail ? 1 : 0,
      'sentAt': sentAt?.toIso8601String(),
    };
  }

  // ساختن از Map
  factory ProcessedImage.fromMap(Map<String, dynamic> map) {
    return ProcessedImage(
      id: map['id'] as int?,
      imagePath: map['imagePath'] as String,
      pestName: map['pestName'] as String,
      commonName: map['commonName'] as String,
      confidence: map['confidence'] as double,
      jsonData: map['jsonData'] as String,
      processedAt: DateTime.parse(map['processedAt'] as String),
      sentViaEmail: (map['sentViaEmail'] as int) == 1,
      sentAt: map['sentAt'] != null ? DateTime.parse(map['sentAt'] as String) : null,
    );
  }
}

// ==================== سرویس پایگاه داده ====================
class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  factory DatabaseService() {
    return _instance;
  }

  DatabaseService._internal();

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, 'insect_detector.db');

    return openDatabase(
      path,
      version: 1,
      onCreate: _createTables,
    );
  }

  Future<void> _createTables(Database db, int version) async {
    await db.execute('''
      CREATE TABLE processed_images (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        imagePath TEXT NOT NULL,
        pestName TEXT NOT NULL,
        commonName TEXT NOT NULL,
        confidence REAL NOT NULL,
        jsonData TEXT NOT NULL,
        processedAt TEXT NOT NULL,
        sentViaEmail INTEGER DEFAULT 0,
        sentAt TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE email_settings (
        id INTEGER PRIMARY KEY,
        senderEmail TEXT NOT NULL,
        senderPassword TEXT NOT NULL,
        recipientEmail TEXT NOT NULL,
        smtpServer TEXT,
        port INTEGER
      )
    ''');
  }

  // ==================== عملیات تصویر ====================
  Future<int> saveProcessedImage(ProcessedImage image) async {
    final db = await database;
    return db.insert('processed_images', image.toMap());
  }

  Future<List<ProcessedImage>> getUnsentImages() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'processed_images',
      where: 'sentViaEmail = ?',
      whereArgs: [0],
      orderBy: 'processedAt DESC',
    );
    return maps.map((map) => ProcessedImage.fromMap(map)).toList();
  }

  Future<List<ProcessedImage>> getAllImages({int limit = 50}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'processed_images',
      orderBy: 'processedAt DESC',
      limit: limit,
    );
    return maps.map((map) => ProcessedImage.fromMap(map)).toList();
  }

  Future<int> markImageAsSent(int imageId) async {
    final db = await database;
    return db.update(
      'processed_images',
      {
        'sentViaEmail': 1,
        'sentAt': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [imageId],
    );
  }

  Future<int> deleteImage(int imageId) async {
    final db = await database;
    return db.delete(
      'processed_images',
      where: 'id = ?',
      whereArgs: [imageId],
    );
  }

  Future<int> getUnsentImageCount() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM processed_images WHERE sentViaEmail = 0',
    );
    return result.isNotEmpty ? (result.first['count'] as int) : 0;
  }

  // ==================== تنظیمات ایمیل ====================
  Future<void> saveEmailSettings({
    required String senderEmail,
    required String senderPassword,
    required String recipientEmail,
    String smtpServer = 'smtp.gmail.com',
    int port = 465,
  }) async {
    final db = await database;
    await db.delete('email_settings'); // حذف تنظیمات قدیمی
    await db.insert('email_settings', {
      'senderEmail': senderEmail,
      'senderPassword': senderPassword,
      'recipientEmail': recipientEmail,
      'smtpServer': smtpServer,
      'port': port,
    });
  }

  Future<Map<String, dynamic>?> getEmailSettings() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('email_settings');
    if (maps.isEmpty) return null;
    return maps.first;
  }

  Future<bool> hasEmailSettings() async {
    final settings = await getEmailSettings();
    return settings != null;
  }
}
