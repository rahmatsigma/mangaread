import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:manga_read/core/api/exceptions.dart';
import 'package:manga_read/features/home/data/repositories/manga_repository_impl.dart';
import 'package:manga_read/models/manga.dart';

// 1. Bikin Class Mock untuk Dio
class MockDio extends Mock implements Dio {}
class MockResponse extends Mock implements Response {}

void main() {
  late MockDio mockDio;
  late MangaRepositoryImpl repository;

  setUp(() {
    mockDio = MockDio();
    repository = MangaRepositoryImpl(dioInstance: mockDio);
  });

  group('MangaRepository TDD', () {
    final tMangaListJson = {
      'data': [
        {
          'title': 'One Piece',
          'endpoint': 'one-piece',
          'image': 'https://image.com/op.jpg',
          'type': 'Manga'
        }
      ]
    };

    test('Harus mengembalikan Right(MangaList) ketika API call sukses (200)', () async {
      // Arrange (Siapkan skenario)
      final mockResponse = MockResponse();
      when(() => mockResponse.statusCode).thenReturn(200);
      when(() => mockResponse.data).thenReturn(tMangaListJson);
      
      // Stubbing method get Dio
      when(() => mockDio.get(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => mockResponse);

      // Act (Jalankan fungsi)
      final result = await repository.getPopularManga(page: 1);

      // Assert (Cek hasil)
      expect(result.isRight(), true); // Berhasil
      result.fold(
        (l) => fail('Should not return failure'),
        (r) {
          expect(r.length, 1);
          expect(r[0]['title'], 'One Piece');
        },
      );
    });

    test('Harus mengembalikan Left(ServerException) ketika terjadi error', () async {
      // Arrange (Simulasi error Dio)
      when(() => mockDio.get(any(), queryParameters: any(named: 'queryParameters')))
          .thenThrow(DioException(
            requestOptions: RequestOptions(path: ''),
            message: 'Server Error',
          ));

      // Act
      final result = await repository.getPopularManga(page: 1);

      // Assert
      expect(result.isLeft(), true); // Gagal
      result.fold(
        (l) => expect(l, isA<ServerException>()),
        (r) => fail('Should not return data'),
      );
    });
  });
}