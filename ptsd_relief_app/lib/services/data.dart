import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:ptsd_relief_app/services/auth.dart';
import 'dart:convert';

class Data extends ChangeNotifier {
  static Data? _instance;

  factory Data() {
    return _instance ??= Data._internal();
  }

  Data._internal();

  Map<String, dynamic> userData = {};
  Future<void> saveFirebaseData(String key, Map<String, dynamic> value) async {
    final ref = FirebaseDatabase.instance.ref();
    await ref.child(key).set(value);
    notifyListeners();
  }

  static Future<Map<String, dynamic>?> getFirebaseData(String key) async {
    final ref = FirebaseDatabase.instance.ref();
    final snapshot = await ref.child(key).get();
    if (snapshot.exists) {
      return Map<String, dynamic>.from(snapshot.value as Map);
    }
    return null;
  }

  Future<bool> setPatientName(String name) async {
    try {
      if (name.isEmpty) {
        return false;
      }
    } catch (e) {
      return false;
    }
    final ref = FirebaseDatabase.instance.ref();
    final uid = Auth().user?.uid;
    await ref.child('users/$uid/name').set(name);

    Map<String, dynamic> userDirectory = {
      'displayName': name,
      'nameLower': name.toLowerCase(),
    };

    await ref.child('userDirectory/$uid').set(userDirectory);
    notifyListeners();
    return true;
  }

  Future<void> saveFirebaseDataToSharedPref(
    String key,
    Map<String, dynamic> value,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    // Convert the map to a JSON string
    final jsonString = jsonEncode(value);
    await prefs.setString(key, jsonString);
    print("notifyListeners?");
    userData = value;
    notifyListeners();
  }

  static Future<Map<String, dynamic>?> getFirebaseDataFromSharedPref(
    String key,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(key);
    if (jsonString != null) {
      final Map<String, dynamic> data = jsonDecode(jsonString);
      return data;
    }
    return null;
  }

  // Live set of this nurse’s patient UIDs (auto-updates when RTDB changes)
  static Stream<Set<String>> nursePatientIdsStream() {
    final nurseUid = Auth().user?.uid;
    if (nurseUid == null) return const Stream.empty();

    final ref = FirebaseDatabase.instance.ref('users/$nurseUid/patients');
    return ref.onValue.map((event) {
      return _patientUidListFromDatabaseValue(event.snapshot.value).toSet();
    });
  }

  // to get one patient data and one only
  static Future<Map<String, dynamic>?> getPatientData(String uid) async {
    try {
      final snap = await FirebaseDatabase.instance.ref('users/$uid').get();

      if (!snap.exists) return null;

      final patient = Map<String, dynamic>.from(snap.value as Map);
      print("PATIENT: $patient");
      return {
        'uid': uid,
        'BPM': int.tryParse((patient['BPM'] ?? 0).toString()) ?? 0,
        'ADM': (patient['ADM'] ?? "").toString(),
        'name': (patient['name'] ?? "").toString(),
        'room': (patient['room'] ?? "").toString(),
        'status': (patient['status'] ?? "").toString(),
      };
    } catch (e) {
      debugPrint('[getPatientData] uid=$uid error: $e');
      return null;
    }
  }

  // firebase permission that didn't let the nurse access:
  //  && root.child('users').child(auth.uid).child('patients').child($uid).exists())

  static Future<List<Map<String, dynamic>>> getPatientsDetails(
    Iterable<dynamic> uids,
  ) async {
    final futures = uids.map((id) => getPatientData(id.toString()));
    print("FUTURES: $futures");
    final results = await Future.wait(futures);
    print("RESULTS: $results");
    final list = results.whereType<Map<String, dynamic>>().toList();
    print("LIST: $list");
    list.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
    return list;
  }

  static Stream<List<Map<String, dynamic>>> nursePatientsDetailsStream() {
    return nursePatientIdsStream().asyncMap((ids) async {
      print("THIS IS EMPTY: $ids");
      if (ids.isEmpty) return <Map<String, dynamic>>[];
      return getPatientsDetails(ids);
    });
  }

  /// Query `userDirectory` by name prefix and exclude any UIDs in [excludeUids].
  /// Assumes userDirectory only contains *patients*.
  static Future<List<Map<String, dynamic>>> searchDirectoryExcluding(
    String query,
    Set<String> excludeUids, {
    int limit = 50,
  }) async {
    final q = query.trim().toLowerCase();

    final snap =
        await FirebaseDatabase.instance
            .ref('userDirectory')
            .orderByChild('nameLower')
            .startAt(q)
            .endAt('$q\uf8ff')
            .get();

    final List<Map<String, dynamic>> results = [];
    if (!snap.exists) return results;

    final data = snap.value;
    if (data is Map) {
      for (final e in data.entries) {
        final uid = e.key.toString();
        if (excludeUids.contains(uid)) continue;

        final value = Map<String, dynamic>.from(e.value as Map);
        value['uid'] = uid;
        results.add(value);
        if (results.length >= limit) break;
      }
    } else if (data is List) {
      // rare shape fallback
      for (int i = 0; i < data.length; i++) {
        final item = data[i];
        if (item == null) continue;
        final uid = i.toString();
        if (excludeUids.contains(uid)) continue;

        final value = Map<String, dynamic>.from(item as Map);
        value['uid'] = uid;
        results.add(value);
        if (results.length >= limit) break;
      }
    }
    return results;
  }

  static Future<bool> addPatient(String uid) async {
    try {
      final data = await getFirebaseDataFromSharedPref('data');
      if (data == null || (data['type']?.toString().toLowerCase() != 'nurse')) {
        debugPrint('[addPatient] Not a nurse or prefs missing: $data');
        return false;
      }

      if (uid.isEmpty) return false;

      final nurseUid = Auth().user?.uid;
      if (nurseUid == null) {
        debugPrint('[addPatient] nurseUid is null (not logged in?)');
        return false;
      }

      final ref = FirebaseDatabase.instance.ref('users/$nurseUid/patients');

      final result = await ref.runTransaction((current) {
        final list = _patientUidListFromDatabaseValue(current);

        if (!list.contains(uid)) {
          list.add(uid);
        }

        return Transaction.success(list);
      });

      if (result.committed) {
        debugPrint('[addPatient] Success: ${result.snapshot.value}');
        return true;
      } else {
        debugPrint('[addPatient] Transaction not committed');
        return false;
      }
    } catch (e) {
      debugPrint('[addPatient] Error: $e');
      return false;
    }
  }

  static List<String> _patientUidListFromDatabaseValue(Object? value) {
    if (value == null) return <String>[];

    if (value is List) {
      return value.whereType<Object>().map((e) => e.toString()).toList();
    }

    if (value is Map) {
      final nestedPatients = value['patients'];
      if (nestedPatients is List) {
        return nestedPatients
            .whereType<Object>()
            .map((e) => e.toString())
            .toList();
      }

      final hasOnlyNumericKeys = value.keys.every(
        (key) => int.tryParse(key.toString()) != null,
      );
      if (hasOnlyNumericKeys) {
        return value.values
            .whereType<Object>()
            .map((e) => e.toString())
            .toList();
      }

      return value.keys.map((e) => e.toString()).toList();
    }

    return <String>[];
  }

  static Future<bool> removePatient(String uid) async {
    try {
      final data = await getFirebaseDataFromSharedPref('data');
      if (data == null || data['type']?.toString().toLowerCase() != 'nurse') {
        debugPrint('[removePatient] Not a nurse or prefs missing: $data');
        return false;
      }

      if (uid.isEmpty) return false;

      final nurseUid = Auth().user?.uid;
      if (nurseUid == null) {
        debugPrint('[removePatient] nurseUid is null (not logged in?)');
        return false;
      }

      bool removed = false;
      final ref = FirebaseDatabase.instance.ref('users/$nurseUid/patients');
      final result = await ref.runTransaction((current) {
        final patients = _patientUidListFromDatabaseValue(current);
        removed = patients.remove(uid);

        if (!removed) {
          return Transaction.abort();
        }

        return Transaction.success(patients);
      });

      if (!result.committed) {
        debugPrint('[removePatient] Patient not found or transaction aborted');
        return false;
      }

      debugPrint('[removePatient] Success: ${result.snapshot.value}');
      return true;
    } catch (e) {
      debugPrint('[removePatient] Error: $e');
      return false;
    }
  }

  static Future<void> changePatientRoom(String uid, String newRoom) async {
    final ref = FirebaseDatabase.instance.ref();
    await ref.child('users/$uid/room').set(newRoom);
  }

  static Future<void> saveStringData(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  static Future<String?> getStringData(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  static Future<int?> getIntData(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(key);
  }

  static Future<void> saveIntData(String key, int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(key, value);
  }

  static Future<void> saveBoolData(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  static Future<bool?> getBoolData(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key);
  }

  static Future<void> saveDoubleData(String key, double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(key, value);
  }

  static Future<double?> getDoubleData(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(key);
  }

  static Future<List<String>?> getStringListData(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(key);
  }

  static Future<void> saveAnomaly(String data) async {
    final prefs = await SharedPreferences.getInstance();
    getStringListData('history').then((value) {
      if (value == null) {
        print("Creating new history list");
        prefs.setStringList('history', [data]);
      } else {
        print("Adding to existing history list");
        value.add(data);
        prefs.setStringList('history', value);
      }
    });
  }

  static Future<void> clearAnomalyHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('history');
  }

  static Future<void> saveStringListData(String key, List<String> value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(key, value);
  }

  static Future<void> removeData(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }

  static Future<void> clearAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  @override
  void dispose() {
    super.dispose();
    // Allow the singleton to be recreated after disposal (e.g., hot restart).
    _instance = null;
  }
}
