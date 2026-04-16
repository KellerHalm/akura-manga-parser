import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:path/path.dart' as p;

class MangaPage {
  final int page;
  final String imageUrl;

  MangaPage({required this.page, required this.imageUrl});

  @override
  String toString() => 'Page $page: $imageUrl';
}

class DesuParser {
  static const String _apiBaseUrl = 'https://desu.uno/manga/api';

  Map<String, String>? _parseUrl(String url) {
    final RegExp regExp = RegExp(
      r'manga\/.*\.(\d+)\/vol\d+\/ch(\d+)(?:\/rus)?',
    );
    final match = regExp.firstMatch(url);

    if (match != null && match.groupCount >= 2) {
      return {'mangaId': match.group(1)!, 'chapterNum': match.group(2)!};
    }
    return null;
  }

  Future<List<MangaPage>> getPages(String chapterUrl) async {
    final ids = _parseUrl(chapterUrl);
    if (ids == null) {
      throw Exception('Не удалось извлечь ID из URL. Проверьте формат ссылки.');
    }

    final mangaId = ids['mangaId'];
    final chapterNum = ids['chapterNum'];

    final mangaInfoResponse = await http.get(
      Uri.parse('$_apiBaseUrl/$mangaId'),
    );
    if (mangaInfoResponse.statusCode != 200) {
      throw Exception(
        'Ошибка при получении информации о манге: ${mangaInfoResponse.statusCode}',
      );
    }

    final mangaData = jsonDecode(mangaInfoResponse.body);
    final List chaptersList = mangaData['response']['chapters']['list'];

    final chapterInfo = chaptersList.firstWhere(
      (c) => c['ch'].toString() == chapterNum,
      orElse: () => null,
    );

    if (chapterInfo == null) {
      throw Exception('Глава с номером $chapterNum не найдена.');
    }

    final chapterInternalId = chapterInfo['id'];

    final chapterResponse = await http.get(
      Uri.parse('$_apiBaseUrl/$mangaId/chapter/$chapterInternalId'),
    );
    if (chapterResponse.statusCode != 200) {
      throw Exception(
        'Ошибка при получении страниц главы: ${chapterResponse.statusCode}',
      );
    }

    final chapterData = jsonDecode(chapterResponse.body);
    final List pagesList = chapterData['response']['pages']['list'];

    return pagesList.map((p) {
      return MangaPage(page: p['page'] as int, imageUrl: p['img'] as String);
    }).toList();
  }

  Future<void> downloadImage(
    String imageUrl,
    String savePath,
    String refererUrl,
  ) async {
    final response = await http.get(
      Uri.parse(imageUrl),
      headers: {
        'Referer': refererUrl,
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36',
      },
    );
    if (response.statusCode == 200) {
      final file = File(savePath);
      await file.writeAsBytes(response.bodyBytes);
      print('Скачано: $savePath');
    } else {
      print('Ошибка скачивания $imageUrl: ${response.statusCode}');
    }
  }

  Future<void> downloadChapterPages(
    String chapterUrl,
    String downloadDir,
  ) async {
    final pages = await getPages(chapterUrl);
    print('Найдено ${pages.length} страниц для скачивания.');

    final Directory dir = Directory(downloadDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    for (var page in pages) {
      final fileName =
          'page_${page.page.toString().padLeft(3, '0')}${p.extension(Uri.parse(page.imageUrl).path)}';
      final savePath = p.join(downloadDir, fileName);
      await downloadImage(page.imageUrl, savePath, chapterUrl);
    }
    print('Скачивание главы завершено.');
  }
}

void main() async {
  final parser = DesuParser();
  const url = 'https://desu.uno/manga/rengoku-deadroll.1400/vol1/ch1/rus';
  const downloadDirectory = 'desu_pages'; 

  print('Начинаю парсинг и скачивание: $url');

  try {
    await parser.downloadChapterPages(url, downloadDirectory);
  } catch (e) {
    print('Произошла ошибка: $e');
  }
}
