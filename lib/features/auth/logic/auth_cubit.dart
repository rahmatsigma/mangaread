import 'dart:async'; // Untuk StreamSubscription
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:manga_read/features/auth/logic/auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final FirebaseAuth _auth;
  late StreamSubscription<User?> _userSubscription;

  AuthCubit({FirebaseAuth? auth}) 
      : _auth = auth ?? FirebaseAuth.instance, 
        super(const AuthState()) {
    init();
  }

  // Mulai mendengarkan perubahan status login (login, logout, dll)
  void init() {
    _userSubscription = _auth.authStateChanges().listen(_onUserChanged);
  }

  // Fungsi ini dipanggil setiap kali Firebase mendeteksi login/logout
  void _onUserChanged(User? user) {
    if (user != null) {
      emit(AuthState(status: AuthStatus.authenticated, user: user));
    } else {
      emit(const AuthState(status: AuthStatus.unauthenticated, user: null));
    }
  }

  // --- FUNGSI BARU: CHECK AUTH STATUS (REFRESH DATA) ---
  // Ini yang dibutuhkan Settings Page untuk update nama setelah diedit
  Future<void> checkAuthStatus() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        // 1. Paksa reload data user dari server Firebase
        await user.reload();

        // 2. Ambil data user terbaru (yang namanya sudah berubah)
        final updatedUser = _auth.currentUser;

        // 3. Emit ulang state Authenticated dengan data baru
        // Ini akan memicu UI (AppBar Home) untuk berubah otomatis
        if (updatedUser != null) {
          emit(AuthState(status: AuthStatus.authenticated, user: updatedUser));
        }
      } catch (e) {
        print("Gagal reload user data: $e");
        // Kalau error (misal gak ada sinyal), biarkan state lama
      }
    }
  }
  // ----------------------------------------------------

  // Fungsi untuk logout
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Jangan lupa tutup subscription saat Cubit ditutup
  @override
  Future<void> close() {
    _userSubscription.cancel();
    return super.close();
  }
}
