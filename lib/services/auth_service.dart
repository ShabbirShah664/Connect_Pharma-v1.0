import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  // ...existing code...
  Future<UserCredential> signUp({
    required String email,
    required String password,
    required String role,
    String? displayName,
    Map<String, dynamic>? meta,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = cred.user!.uid;
      if (displayName != null && displayName.isNotEmpty) {
        await cred.user!.updateDisplayName(displayName);
      }

      final data = {
        'uid': uid,
        'email': email,
        'role': role,
        'displayName': displayName ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        ...?meta,
      };

      final batch = _db.batch();
      final usersRef = _db.collection('users').doc(uid);
      batch.set(usersRef, data);

      final roleCollection = role == 'pharmacist'
          ? 'pharmacists'
          : role == 'rider'
              ? 'riders'
              : 'users';
      final roleRef = _db.collection(roleCollection).doc(uid);
      batch.set(roleRef, data);

      // optional: create role meta doc once
      final roleMetaRef = _db.collection('role_meta').doc(role);
      final roleMetaSnap = await roleMetaRef.get();
      if (!roleMetaSnap.exists) {
        batch.set(roleMetaRef, {'createdAt': FieldValue.serverTimestamp()});
      }

      await batch.commit();
      return cred;
    } on FirebaseAuthException catch (e) {
      throw Exception('FirebaseAuthException(${e.code}): ${e.message}');
    } catch (e) {
      throw Exception('Sign up failed: $e');
    }
  }
// ...existing code...

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return cred;
    } on FirebaseAuthException catch (e) {
      throw Exception('FirebaseAuthException(${e.code}): ${e.message}');
    } catch (e) {
      throw Exception('Sign in failed: $e');
    }
  }
  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<String?> fetchRole(String uid) async {
    final snap = await _db.collection('users').doc(uid).get();
    if (!snap.exists) return null;
    final data = snap.data();
    return data != null && data.containsKey('role') ? (data['role'] as String) : null;
  }
}


final authService = AuthService();
