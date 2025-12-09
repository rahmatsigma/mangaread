import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:manga_read/core/api/dio_client.dart';
import 'package:manga_read/core/api/exceptions.dart';
import 'package:manga_read/features/home/data/repositories/i_manga_repository.dart';
import 'package:manga_read/models/manga.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Wajib ada buat Database

class MangaRepositoryImpl implements IMangaRepository {
  final Dio dio;

  MangaRepositoryImpl({Dio? dioInstance}) 
      : dio = dioInstance ?? DioClient().dio;

  @override 
  Future<bool> isMangaFavorite(String uid, String mangaId) async { 
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('favorites')
          .doc(mangaId)
          .get();

      return doc.exists;
    } catch (e) {
      print("Error cek favorite: $e");
      return false;
    }
  }

  @override
  Future<void> toggleFavorite(
    String uid,
    Manga manga,
    bool isCurrentlyFavorite,
  ) async {
    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('favorites')
        .doc(manga.id);

    if (isCurrentlyFavorite) {
      // Kalau sudah ada, hapus (Unlike)
      await docRef.delete();
    } else {
      // Kalau belum ada, simpan (Like)
      await docRef.set({
        'id': manga.id,
        'title': manga.title,
        'coverUrl': manga.imageUrl,
        'type': manga.type,
        'addedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  @override
  Future<void> addToHistory(
    String uid,
    Manga manga,
    String chapterTitle,
    String chapterId,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('history')
          .doc(manga.id)
          .set({
            'mangaId': manga.id,
            'title': manga.title,
            'coverUrl': manga.imageUrl,
            'lastChapter': chapterTitle,
            'chapterId': chapterId,
            'lastReadAt': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      print("Gagal simpan history: $e");
    }
  }

  // ==========================================
  // BAGIAN API (KOMIKU)
  // ==========================================

  @override
  Future<Either<Failure, MangaList>> getPopularManga({
    required int page,
  }) async {
    try {
      final response = await dio.get(
        '/api/comics',
        queryParameters: {'page': page},
      );

      final List<dynamic> rawData = _extractList(response.data);

      final MangaList mangaList = rawData.map((json) {
        final mangaObj = Manga.fromApi(json);
        return {
          'id': mangaObj.id,
          'title': mangaObj.title,
          'coverUrl': mangaObj.imageUrl,
          'type': mangaObj.type,
          'status': mangaObj.status,
        };
      }).toList();

      return Right(mangaList);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return Left(NotFoundException('Manga not found'));
      }
      return Left(ServerException(e.message ?? 'Unknown error'));
    } catch (e) {
      return Left(ServerException(e.toString()));
    }
  }

  @override
  Future<Either<Failure, MangaList>> searchManga({
    required String query,
  }) async {
    try {
      final encodedQuery = Uri.encodeComponent(query);
      final response = await dio.get(
        '/api/search',
        queryParameters: {'q': encodedQuery},
      );

      final List<dynamic> rawData = _extractList(response.data);

      final MangaList mangaList = rawData.map((json) {
        final mangaObj = Manga.fromApi(json);
        return {
          'id': mangaObj.id,
          'title': mangaObj.title,
          'coverUrl': mangaObj.imageUrl,
          'type': mangaObj.type,
          'status': mangaObj.status,
        };
      }).toList();

      return Right(mangaList);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return Left(NotFoundException('Manga not found'));
      }
      return Left(ServerException(e.message ?? 'Unknown error'));
    }
  }

  @override
  Future<Either<Failure, Manga>> getMangaDetail({required String id}) async {
    try {
      print(">>> REQUEST DETAIL ID: $id");
      final response = await dio.get('/api/comics/$id');

      if (response.statusCode == 200) {
        final dynamic rawData = response.data['data'] ?? response.data;
        final mangaDetail = Manga.fromApi(rawData);
        return Right(mangaDetail);
      } else {
        return Left(ServerException('Gagal: Kode ${response.statusCode}'));
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return Left(NotFoundException('Manga tidak ditemukan'));
      }
      return Left(ServerException(e.message ?? 'Koneksi bermasalah'));
    } catch (e) {
      return Left(ServerException('Error parsing: $e'));
    }
  }

  @override
  Future<Either<Failure, List<String>>> getChapterImages({
    required String chapterId,
  }) async {
    try {
      print(">>> REQUEST CHAPTER ID: $chapterId");
      final response = await dio.get('/api/chapters/$chapterId');

      if (response.statusCode == 200) {
        final data = response.data['data'];
        List<String> imageUrls = [];

        if (data != null && data['images'] is List) {
          final List images = data['images'];
          imageUrls = images
              .map((img) {
                return (img['url'] ?? '').toString();
              })
              .where((url) => url.isNotEmpty)
              .toList();
        }

        print(">>> DAPAT ${imageUrls.length} GAMBAR");
        return Right(imageUrls);
      } else {
        return Left(
          ServerException('Gagal load chapter: ${response.statusCode}'),
        );
      }
    } on DioException catch (e) {
      return Left(ServerException(e.message ?? 'Error Koneksi'));
    } catch (e) {
      return Left(ServerException('Error parsing: $e'));
    }
  }

  // 1. STREAM FAVORITE (Mendengarkan data favorite secara realtime)
  Stream<List<Manga>> getFavoritesStream(String uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('favorites')
        .orderBy('addedAt', descending: true) // Urutkan dari yang baru ditambah
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            // Kita mapping manual dari Firestore ke Object Manga biar aman
            return Manga(
              id: data['id'],
              title: data['title'],
              imageUrl:
                  data['coverUrl'] ?? '', // Nama field di firestore 'coverUrl'
              genres: [], // Data minimalis
              status: 'Unknown',
              author: '',
              type: data['type'],
            );
          }).toList();
        });
  }

  // 2. STREAM HISTORY
  Stream<List<Map<String, dynamic>>> getHistoryStream(String uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('history')
        .orderBy(
          'lastReadAt',
          descending: true,
        ) // Yang terakhir dibaca paling atas
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => doc.data()).toList();
        });
  }

  // Helper
  List _extractList(dynamic data) {
    if (data == null) return [];
    if (data is List) return data;
    if (data is Map) {
      if (data['data'] is List) return data['data'];
      if (data['results'] is List) return data['results'];
      if (data['comics'] is List) return data['comics'];
      if (data['items'] is List) return data['items'];
      return [data];
    }
    return [];
  }
}
