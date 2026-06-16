import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  FirebaseAuth get auth => FirebaseAuth.instance;
  FirebaseFirestore get firestore => FirebaseFirestore.instance;

  bool get isInitialized => _initialized;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    await Firebase.initializeApp();
    _initialized = true;
  }

  // --- Authentication ---
  User? get currentUser => auth.currentUser;

  Stream<User?> get authStateChanges => auth.authStateChanges();

  Future<UserCredential> signInAnonymously() async {
    return await auth.signInAnonymously();
  }

  Future<UserCredential> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    return await auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<UserCredential> createUserWithEmailAndPassword(
    String email,
    String password,
  ) async {
    return await auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    await auth.signOut();
  }

  Future<void> resetPassword(String email) async {
    await auth.sendPasswordResetEmail(email: email);
  }

  // --- Firestore ---
  Future<DocumentSnapshot> getUserData(String userId) async {
    return await firestore.collection('users').doc(userId).get();
  }

  Future<void> setUserData(String userId, Map<String, dynamic> data) async {
    try {
      debugPrint("DEBUG: Inizio scrittura su Firestore...");
      await firestore
          .collection('users')
          .doc(userId)
          .set(data)
          .timeout(const Duration(seconds: 5));
      debugPrint("DEBUG: Scrittura avvenuta con successo!");
    } catch (e) {
      debugPrint("DEBUG: ERRORE CRITICO: $e");
    }
  }

  Future<void> updateUserData(String userId, Map<String, dynamic> data) async {
    await firestore.collection('users').doc(userId).update(data);
  }

  Stream<QuerySnapshot> getUserRecipes(String userId) {
    return firestore
        .collection('users')
        .doc(userId)
        .collection('recipes')
        .snapshots();
  }

  Future<void> addRecipe(String userId, Map<String, dynamic> recipe) async {
    await firestore
        .collection('users')
        .doc(userId)
        .collection('recipes')
        .add(recipe);
  }

  Future<void> updateRecipe(
    String userId,
    String recipeId,
    Map<String, dynamic> data,
  ) async {
    await firestore
        .collection('users')
        .doc(userId)
        .collection('recipes')
        .doc(recipeId)
        .update(data);
  }

  Future<void> deleteRecipe(String userId, String recipeId) async {
    await firestore
        .collection('users')
        .doc(userId)
        .collection('recipes')
        .doc(recipeId)
        .delete();
  }

  Future<void> syncUserData(
    String userId,
    Map<String, dynamic> localData,
  ) async {
    debugPrint("--- INIZIO SALVATAGGIO FIREBASE ---");
    debugPrint("UserId: $userId");

    try {
      debugPrint("Tentativo di connessione a Firestore...");
      final docRef = firestore.collection('users').doc(userId);
      final doc = await docRef.get();

      debugPrint("Documento esiste: ${doc.exists}");

      if (!doc.exists) {
        debugPrint("Creazione nuovo documento...");
        await docRef.set(localData);
        debugPrint("--- SALVATAGGIO (NUOVO) RIUSCITO ---");
      } else {
        debugPrint("Aggiornamento documento esistente...");
        await docRef.update(localData);
        debugPrint("--- SALVATAGGIO (UPDATE) RIUSCITO ---");
      }
    } catch (e) {
      debugPrint("--- ERRORE DURANTE IL SALVATAGGIO FIREBASE ---");
      debugPrint(e.toString());
    }
  }

  Future<Map<String, dynamic>?> fetchUserData(String userId) async {
    final doc = await firestore.collection('users').doc(userId).get();
    if (doc.exists) {
      return doc.data() as Map<String, dynamic>;
    }
    return null;
  }
}
