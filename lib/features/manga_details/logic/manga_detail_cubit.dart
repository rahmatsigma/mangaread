import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:manga_read/features/home/data/repositories/i_manga_repository.dart';
import 'package:manga_read/models/manga.dart'; // Pastikan import Model Manga
import 'manga_detail_state.dart';

class MangaDetailCubit extends Cubit<MangaDetailState> {
  final IMangaRepository _repository;

  MangaDetailCubit(this._repository) : super(MangaDetailInitial());

  // 1. Load Detail
  Future<void> getMangaDetail(String id, {String? userId}) async {
    emit(MangaDetailLoading());

    final result = await _repository.getMangaDetail(id: id);

    result.fold(
      (failure) => emit(MangaDetailError(failure.message)), 
      (manga) async {
        bool isFav = false;

        // Code jadi lebih bersih, langsung panggil _repository
        if (userId != null) {
          // Tidak perlu try-catch di sini jika di repository sudah handle error (return false)
          isFav = await _repository.isMangaFavorite(userId, id);
        }

        emit(MangaDetailLoaded(manga, isFavorite: isFav));
      }
    );
  }

  // 2. Simpan History
  Future<void> saveHistoryIfLoggedIn(
    String? userId,
    String chapterTitle,
    String chapterId,
  ) async {
    // Pastikan state sudah loaded sebelum akses data manga
    if (state is MangaDetailLoaded && userId != null) {
      final currentManga = (state as MangaDetailLoaded).manga;
      
      // Langsung panggil tanpa casting
      await _repository.addToHistory(
        userId,
        currentManga,
        chapterTitle,
        chapterId,
      );
    }
  }

  // 3. Toggle Favorite
  Future<void> toggleFavorite(String userId) async {
    if (state is MangaDetailLoaded) {
      final currentState = state as MangaDetailLoaded;
      final currentManga = currentState.manga;
      final currentStatus = currentState.isFavorite;

      // Optimistic Update UI
      emit(currentState.copyWith(isFavorite: !currentStatus));

      try {
        // Langsung panggil tanpa casting
        await _repository.toggleFavorite(
          userId,
          currentManga,
          currentStatus,
        );
      } catch (e) {
        // Rollback jika gagal
        emit(currentState.copyWith(isFavorite: currentStatus));
      }
    }
  }
}