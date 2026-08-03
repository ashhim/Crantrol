import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firebase_service.dart';
import 'package:logger/logger.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();
  final Logger _logger = Logger();

  User? _user;
  bool _isLoading = false;
  String? _error;
  bool _isAuthenticated = false;

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _isAuthenticated;

  AuthProvider() {
    _initializeAuth();
  }

  void _initializeAuth() {
    _user = _firebaseService.currentUser;
    _isAuthenticated = _firebaseService.isAuthenticated;
    
    _firebaseService.authStateChanges.listen((user) {
      _user = user;
      _isAuthenticated = user != null;
      _logger.d('Auth state changed: user is ${user?.email ?? "null"}');
      notifyListeners();
    });
  }

  Future<bool> signIn(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _user = await _firebaseService.signIn(email, password);
      _isAuthenticated = true;
      _logger.d('Sign in successful for $email');
      return true;
    } catch (e) {
      _error = e.toString();
      _logger.e('Sign in failed: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _firebaseService.signOut();
      _user = null;
      _isAuthenticated = false;
      _logger.d('Sign out successful');
    } catch (e) {
      _error = e.toString();
      _logger.e('Sign out failed: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
