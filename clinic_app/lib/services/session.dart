import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_user.dart';

class Session extends ChangeNotifier {
  AppUser? user;
  String? token;
  bool ready = false;

  bool get isLoggedIn => user != null && token != null;

  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final savedToken = prefs.getString('token');
    final savedUser = prefs.getString('user');
    if (savedToken != null && savedUser != null) {
      token = savedToken;
      user = AppUser.fromJson(jsonDecode(savedUser) as Map<String, dynamic>);
    }
    ready = true;
    notifyListeners();
  }

  Future<void> login(String jwt, AppUser appUser) async {
    token = jwt;
    user = appUser;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', jwt);
    await prefs.setString('user', jsonEncode(appUser.toJson()));
    notifyListeners();
  }

  Future<void> logout() async {
    token = null;
    user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('user');
    notifyListeners();
  }
}
