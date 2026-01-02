import 'package:cloud_firestore/cloud_firestore.dart';

class ReminderService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static Future<void> addReminder({
    required String pharmacistId,
    required String medicineName,
    required String userName,
    required String frequency, // Weekly, Monthly
    required DateTime startDate,
  }) async {
    try {
      await _db.collection('reminders').add({
        'pharmacistId': pharmacistId,
        'medicineName': medicineName,
        'userName': userName,
        'frequency': frequency,
        'startDate': Timestamp.fromDate(startDate),
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to add reminder: $e');
    }
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> streamReminders(String pharmacistId) {
    return _db
        .collection('reminders')
        .where('pharmacistId', isEqualTo: pharmacistId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  static Future<void> deleteReminder(String id) async {
    try {
      await _db.collection('reminders').doc(id).delete();
    } catch (e) {
      throw Exception('Failed to delete reminder: $e');
    }
  }
}
