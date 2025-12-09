import 'package:bloc_test/bloc_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:manga_read/features/auth/logic/auth_cubit.dart';
import 'package:manga_read/features/auth/logic/auth_state.dart';

// 1. Bikin Class Mock untuk Firebase
class MockFirebaseAuth extends Mock implements FirebaseAuth {}
class MockUser extends Mock implements User {}

void main() {
  late MockFirebaseAuth mockAuth;
  late MockUser mockUser;
  late AuthCubit authCubit;

  setUp(() {
    mockAuth = MockFirebaseAuth();
    mockUser = MockUser();
    
    // Setup stream mock agar tidak error saat init() dipanggil
    when(() => mockAuth.authStateChanges()).thenAnswer((_) => Stream.value(null));
  });

  tearDown(() {
    authCubit.close();
  });

  group('AuthCubit TDD', () {
    test('Initial state harus unknown dan user null', () {
      authCubit = AuthCubit(auth: mockAuth);
      expect(authCubit.state, const AuthState(status: AuthStatus.unknown));
    });

    blocTest<AuthCubit, AuthState>(
      'Emit [authenticated] ketika user berhasil login',
      build: () {
        // Simulasi stream mengembalikan User object
        when(() => mockAuth.authStateChanges()).thenAnswer((_) => Stream.value(mockUser));
        return AuthCubit(auth: mockAuth);
      },
      // Karena init() dipanggil di constructor, state akan langsung berubah
      verify: (cubit) {
         expect(cubit.state.status, AuthStatus.authenticated);
         expect(cubit.state.user, mockUser);
      },
    );

    blocTest<AuthCubit, AuthState>(
      'Emit [unauthenticated] ketika user logout',
      build: () {
        // Simulasi stream mengembalikan null (tidak ada user)
        when(() => mockAuth.authStateChanges()).thenAnswer((_) => Stream.value(null));
        return AuthCubit(auth: mockAuth);
      },
      verify: (cubit) {
         expect(cubit.state.status, AuthStatus.unauthenticated);
         expect(cubit.state.user, null);
      },
    );
    
    blocTest<AuthCubit, AuthState>(
      'Fungsi signOut memanggil FirebaseAuth.signOut',
      build: () {
        when(() => mockAuth.signOut()).thenAnswer((_) async {});
        // Setup stream default
        when(() => mockAuth.authStateChanges()).thenAnswer((_) => Stream.value(null));
        return AuthCubit(auth: mockAuth);
      },
      act: (cubit) => cubit.signOut(),
      verify: (_) {
        verify(() => mockAuth.signOut()).called(1);
      },
    );
  });
}