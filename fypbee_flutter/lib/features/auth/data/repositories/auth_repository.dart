import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

class AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> registerUser({
    required String studentId,
    required String name,
    required String email,
    required String password,
    required String role,
    required String enrollTrimester,
  }) async {
    final registrationApp = await Firebase.initializeApp(
      name: 'studentRegistration_${DateTime.now().microsecondsSinceEpoch}',
      options: Firebase.app().options,
    );

    final registrationAuth = FirebaseAuth.instanceFor(app: registrationApp);
    final registrationFirestore = FirebaseFirestore.instanceFor(
      app: registrationApp,
    );

    final credential = await registrationAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final uid = credential.user!.uid;

    await registrationFirestore.collection('users').doc(uid).set({
      'uid': uid,
      'studentId': studentId,
      'name': name,
      'email': email,
      'role': role,
      'status': 'pending',
      'enrollTrimester': enrollTrimester,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await registrationAuth.signOut();
  }

  Future<Map<String, dynamic>?> loginUser({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    final uid = credential.user!.uid;
    final doc = await _firestore.collection('users').doc(uid).get();

    if (!doc.exists) {
      await _auth.signOut();
      return null;
    }

    final userData = doc.data();

    if (userData == null || userData['status'] != 'approved') {
      await _auth.signOut();
    }

    return userData;
  }

  Future<void> logout() async {
    await _auth.signOut();
  }
}
