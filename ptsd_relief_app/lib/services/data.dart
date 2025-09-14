import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:ptsd_relief_app/services/auth.dart';
import 'dart:convert';

class Data extends ChangeNotifier {
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

  // Patient Search Function (Nurse only)
  static Future<List<Map<String, dynamic>>> searchPatientsByName(
    String query,
  ) async {
    final ref = FirebaseDatabase.instance.ref();
    final snapshot =
        await ref
            .child('userDirectory')
            .orderByChild('nameLower')
            .startAt(query.toLowerCase())
            .endAt('${query.toLowerCase()}\uf8ff')
            .get();
    List<Map<String, dynamic>> results = [];
    if (snapshot.exists) {
      final data = snapshot.value as Map<dynamic, dynamic>;
      data.forEach((key, value) {
        value['uid'] = key;
        results.add(Map<String, dynamic>.from(value));
      });
    }
    return results;
  }

  static Future<bool> addPatient(String uid) async {
    // check if self is nurse
    final data = await getFirebaseDataFromSharedPref('data');
    if (data == null || data['type'] != 'nurse') {
      return false;
    }
    if (uid.isEmpty) {
      return false;
    }

    final ref = FirebaseDatabase.instance.ref();
    final nurseUid = Auth().user?.uid;
    // get existing patients list of nurse
    final snapshot = await ref.child('users/$nurseUid/patients').get();
    List<dynamic> patients = [];
    if (snapshot.exists) {
      patients = List<dynamic>.from(snapshot.value as List);
    }
    // check if patient already exists
    if (patients.contains(uid)) {
      return false;
    }
    patients.add(uid);

    // add to patients list of nurse
    await ref.child('users/$nurseUid/patients').set(patients);
    return true;
  }

  static Future<bool> removePatient(String uid) async {
    // check if self is nurse
    final data = await getFirebaseDataFromSharedPref('data');
    if (data == null || data['type'] != 'nurse') {
      return false;
    }
    if (uid.isEmpty) {
      return false;
    }

    final ref = FirebaseDatabase.instance.ref();
    final nurseUid = Auth().user?.uid;
    // get existing patients list of nurse
    final snapshot = await ref.child('users/$nurseUid/patients').get();
    List<dynamic> patients = [];
    if (snapshot.exists) {
      patients = List<dynamic>.from(snapshot.value as List);
    }
    // check if patient exists
    if (!patients.contains(uid)) {
      return false;
    }
    patients.remove(uid);

    // remove from patients list of nurse
    await ref.child('users/$nurseUid/patients').set(patients);
    return true;
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
}
