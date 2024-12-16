import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'api_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final ApiService _apiService = ApiService();

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Stream of auth changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in with email and password
  Future<Map<String, dynamic>> signInWithEmailPassword(String email, String password) async {
    try {
      // First authenticate with Firebase
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Then sync with backend
      final customerData = await _apiService.login(email: email);
      return customerData;
    } catch (e) {
      if (e is FirebaseAuthException) {
        throw ApiException(
          message: e.message ?? 'Authentication failed',
          statusCode: 401,
        );
      }
      rethrow;
    }
  }

  // Register with email and password
  Future<Map<String, dynamic>> registerWithEmailPassword({
    required String email,
    required String password,
    required String firstName,
    String? lastName,
    String? phone,
  }) async {
    try {
      // First create Firebase account
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Then register with backend
      final customerData = await _apiService.register(
        email: email,
        firstName: firstName,
        lastName: lastName,
        phone: phone,
      );
      
      return customerData;
    } catch (e) {
      // If backend registration fails, delete the Firebase user
      if (_auth.currentUser != null) {
        await _auth.currentUser!.delete();
      }
      if (e is FirebaseAuthException) {
        throw ApiException(
          message: e.message ?? 'Registration failed',
          statusCode: 401,
        );
      }
      rethrow;
    }
  }

  // Start Google Sign In process (Firebase auth only)
  Future<GoogleSignInAccount?> startGoogleSignIn() async {
    try {
      // Step 1: Google Sign In
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw ApiException(
          message: 'Google sign in was cancelled',
          statusCode: 401,
        );
      }

      // Step 2: Get auth details
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Step 3: Firebase auth
      await _auth.signInWithCredential(credential);
      
      return googleUser;
    } catch (e) {
      if (e is FirebaseAuthException) {
        throw ApiException(
          message: e.message ?? 'Google sign-in failed: Firebase Auth Error',
          statusCode: 401,
        );
      } else if (e is ApiException) {
        rethrow;
      }
      throw ApiException(
        message: e.toString(),
        statusCode: 401,
      );
    }
  }

  // Complete Google Sign In process (backend sync)
  Future<Map<String, dynamic>> completeGoogleSignIn(GoogleSignInAccount googleUser) async {
    try {
      // Get the Firebase token
      final token = await _auth.currentUser?.getIdToken();
      if (token == null) {
        throw ApiException(
          message: 'No authentication token available',
          statusCode: 401,
        );
      }

      // Sync with backend
      final customerData = await _apiService.socialAuth(
        provider: 'GOOGLE',
        email: googleUser.email,
        firstName: googleUser.displayName?.split(' ').first ?? '',
        lastName: googleUser.displayName?.split(' ').skip(1).join(' '),
        imageUrl: googleUser.photoUrl,
      );
      
      if (customerData is! Map<String, dynamic>) {
        throw ApiException(
          message: 'Invalid response format from server',
          statusCode: 500,
        );
      }

      print('Customer data from backend: $customerData');
      return customerData;
    } catch (e) {
      print('Error syncing with backend after Google Sign In: $e');
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException(
        message: 'Failed to sync with backend: ${e.toString()}',
        statusCode: 500,
      );
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  // Password reset
  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // Get user profile from backend
  Future<Map<String, dynamic>> getUserProfile() async {
    final customerDetails = await _apiService.getCurrentCustomer();
    return customerDetails.toJson();
  }

  // Update user profile
  Future<Map<String, dynamic>> updateProfile({
    String? firstName,
    String? lastName,
    String? phone,
  }) async {
    final customerDetails = await _apiService.updateProfile(
      firstName: firstName,
      lastName: lastName,
      phone: phone,
    );
    return customerDetails.toJson();
  }
}
