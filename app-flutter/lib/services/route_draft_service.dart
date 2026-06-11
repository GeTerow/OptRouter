import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../domain/app_failure.dart';
import '../domain/route_draft.dart';
import '../domain/saved_route_summary.dart';
import '../domain/user_settings.dart';

class RouteDraftService {
  RouteDraftService({
    FirebaseFirestore? firestore,
    FirebaseAuth? firebaseAuth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;

  Future<String> saveRouteDraft(
    RouteDraft draft, {
    String? routeId,
  }) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw const AppFailure(
        kind: AppFailureKind.validation,
        message: 'Faça login para salvar a rota.',
      );
    }

    final routes = _routesFor(user.uid);
    final doc = routeId == null ? routes.doc() : routes.doc(routeId);
    final now = FieldValue.serverTimestamp();

    try {
      await doc.set(
        {
          'title': draft.title,
          'origin': draft.origin,
          'destination': draft.destination,
          'stops': draft.stops,
          'addressOrder': draft.orderedAddresses,
          'status': 'draft',
          'updatedAt': now,
          if (routeId == null) 'createdAt': now,
        },
        SetOptions(merge: true),
      ).timeout(const Duration(seconds: 12));
    } on FirebaseException catch (error) {
      throw AppFailure(
        kind: AppFailureKind.validation,
        message: 'Não foi possível salvar a rota no Firebase.',
        technicalMessage: error.message ?? error.code,
      );
    } on TimeoutException {
      throw const AppFailure(
        kind: AppFailureKind.timeout,
        message:
            'O Firebase demorou demais para responder. Verifique se o Firestore está habilitado.',
      );
    }

    return doc.id;
  }

  Future<List<SavedRouteSummary>> listRoutes({int limit = 50}) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return const [];

    final snapshot = await _routesFor(user.uid)
        .orderBy('updatedAt', descending: true)
        .limit(limit)
        .get()
        .timeout(const Duration(seconds: 12));

    return snapshot.docs
        .map((doc) => _summaryFromDoc(doc.id, doc.data()))
        .whereType<SavedRouteSummary>()
        .toList();
  }

  Future<UserSettings> getSettings() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return const UserSettings();

    final snapshot =
        await _settingsFor(user.uid).get().timeout(const Duration(seconds: 12));
    final data = snapshot.data();
    if (data == null) return const UserSettings();

    return UserSettings(
      defaultOrigin: (data['defaultOrigin'] as String?)?.trim() ?? '',
      defaultDestination: (data['defaultDestination'] as String?)?.trim() ?? '',
    );
  }

  Future<void> saveSettings(UserSettings settings) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw const AppFailure(
        kind: AppFailureKind.validation,
        message: 'Faça login para salvar as configurações.',
      );
    }

    await _settingsFor(user.uid).set(
      {
        'defaultOrigin': settings.defaultOrigin.trim(),
        'defaultDestination': settings.defaultDestination.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    ).timeout(const Duration(seconds: 12));
  }

  Future<void> deleteSavedRoutes() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return;

    final snapshot = await _routesFor(user.uid)
        .limit(500)
        .get()
        .timeout(const Duration(seconds: 12));
    if (snapshot.docs.isEmpty) return;

    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit().timeout(const Duration(seconds: 12));
  }

  CollectionReference<Map<String, dynamic>> _routesFor(String uid) {
    return _firestore.collection('users').doc(uid).collection('routes');
  }

  DocumentReference<Map<String, dynamic>> _settingsFor(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('settings')
        .doc('profile');
  }

  SavedRouteSummary? _summaryFromDoc(
    String id,
    Map<String, dynamic> data,
  ) {
    final order = (data['addressOrder'] as List?)
        ?.whereType<String>()
        .map((address) => address.trim())
        .where((address) => address.isNotEmpty)
        .toList();
    if (order == null || order.length < 2) return null;

    final updatedAt = data['updatedAt'];
    return SavedRouteSummary(
      id: id,
      title: (data['title'] as String?)?.trim().isNotEmpty == true
          ? (data['title'] as String).trim()
          : order.last,
      origin: (data['origin'] as String?)?.trim().isNotEmpty == true
          ? (data['origin'] as String).trim()
          : order.first,
      destination: (data['destination'] as String?)?.trim().isNotEmpty == true
          ? (data['destination'] as String).trim()
          : order.last,
      addressOrder: order,
      updatedAt: updatedAt is Timestamp ? updatedAt.toDate() : null,
    );
  }
}
