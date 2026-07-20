import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_user.dart';

class Session extends ChangeNotifier {
  AppUser? user;
  String? token;
  bool ready = false;
  ThemeMode themeMode = ThemeMode.system;

  bool get isLoggedIn => user != null && token != null;

  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final savedToken = prefs.getString('token');
    final savedUser = prefs.getString('user');
    if (savedToken != null && savedUser != null) {
      token = savedToken;
      user = AppUser.fromJson(jsonDecode(savedUser) as Map<String, dynamic>);
    }
    themeMode = _themeFromName(prefs.getString('themeMode'));
    ready = true;
    notifyListeners();
  }

  static ThemeMode _themeFromName(String? name) {
    switch (name) {
      case 'dark':
        return ThemeMode.dark;
      case 'light':
        return ThemeMode.light;
      default:
        return ThemeMode.system;
    }
  }

  // يبدّل بين الفاتح والداكن (أي وضع نظام يُعامَل كفاتح عند أول ضغطة)
  Future<void> toggleTheme() async {
    themeMode = themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeMode', themeMode.name);
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
