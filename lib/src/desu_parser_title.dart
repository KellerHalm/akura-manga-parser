import 'dart:convert';
import 'package:http/http.dart' as http;

class MangaInfo {
  final int id;
  final String name;
  final String? russian;
  final String url;
  final String description;
  final String status;
  final String transStatus;
  final double score;
  final int views;
  final List<String> genres;
  final List<String> authors;
  final String coverUrl;
  final List<Chapter> chapters;

  MangaInfo({
    required this.id,
    required this.name,
    this.russian,
    required this.url,
    required this.description,
    required this.status,
    required this.transStatus,
    required this.score,
    required this.views,
    required this.genres,
    required this.authors,
    required this.coverUrl,
    required this.chapters,
  });

  factory MangaInfo.fromJson(Map<String, dynamic> json) {
    var genresList = (json['genres'] as List?)
            ?.map((g) => g['russian']?.toString() ?? g['text']?.toString() ?? '')
            .where((s) => s.isNotEmpty)
            .toList() ??
        [];

    var authorsList = (json['authors'] as List?)
            ?.map((a) => a['people_name']?.toString() ?? '')
            .where((s) => s.isNotEmpty)
            .toList() ??
        [];

    var chaptersList = (json['chapters']?['list'] as List?)
            ?.map((c) => Chapter.fromJson(c))
            .toList() ??
        [];

    return MangaInfo(
      id: json['id'],
      name: json['name'],
      russian: json['russian'],
      url: json['url'],
      description: json['description'] ?? '',
      status: json['status'] ?? '',
      transStatus: json['trans_status'] ?? '',
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      views: json['views'] ?? 0,
      genres: List<String>.from(genresList),
      authors: List<String>.from(authorsList),
      coverUrl: json['image']?['original'] ?? '',
      chapters: chaptersList,
    );
  }
}

class Chapter {
  final int id;
  final String vol;
  final String ch;
  final String title;
  final int date;

  Chapter({
    required this.id,
    required this.vol,
    required this.ch,
    required this.title,
    required this.date,
  });

  factory Chapter.fromJson(Map<String, dynamic> json) {
    return Chapter(
      id: json['id'],
      vol: json['vol'].toString(),
      ch: json['ch'].toString(),
      title: json['title'] ?? '',
      date: json['date'] ?? 0,
    );
  }
}

class DesuParser {
  static const String apiBase = 'https://desu.uno/manga/api';

  String? extractId(String url) {
    final regExp = RegExp(r'\.(\d+)/?$');
    return regExp.firstMatch(url)?.group(1);
  }

  Future<MangaInfo> fetchManga(String url) async {
    final id = extractId(url);
    if (id == null) throw Exception('Неверный формат ссылки');

    final response = await http.get(Uri.parse('$apiBase/$id'));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return MangaInfo.fromJson(data['response']);
    } else {
      throw Exception('Ошибка загрузки: ${response.statusCode}');
    }
  }
}

void main() async {
  final parser = DesuParser();
  const url = 'https://desu.uno/manga/rengoku-deadroll.1400/';

  try {
    print('Парсинг тайтла: $url...');
    final manga = await parser.fetchManga(url);

    print('\n=== ОСНОВНАЯ ИНФОРМАЦИЯ ===');
    print('ID: ${manga.id}');
    print('Название: ${manga.name}');
    print('Русское название: ${manga.russian}');
    print('Статус: ${manga.status} (${manga.transStatus})');
    print('Рейтинг: ${manga.score}');
    print('Просмотров: ${manga.views}');
    print('Обложка: ${manga.coverUrl}');
    print('Авторы: ${manga.authors.join(', ')}');
    print('Жанры: ${manga.genres.join(', ')}');
    
    print('\n=== ОПИСАНИЕ ===');
    print(manga.description);

    print('\n=== СПИСОК ГЛАВ (Всего: ${manga.chapters.length}) ===');
    for (var chapter in manga.chapters.take(10)) {
      print('Том ${chapter.vol} Глава ${chapter.ch}: ${chapter.title}');
    }
    if (manga.chapters.length > 10) print('...');

  } catch (e) {
    print('Ошибка: $e');
  }
}
