import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

class RemangaDownloader {
  final String baseUrl = 'https://remanga.org';
  final String apiBaseUrl = 'https://remanga.org/api';
  final Map<String, String> headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Accept': 'application/json, text/plain, */*',
    'Referer': 'https://remanga.org/',
  };

  Future<void> downloadChapter(String chapterId) async {
    print('Получение данных главы $chapterId...');
    
    final url = Uri.parse('$apiBaseUrl/titles/chapters/$chapterId/');
    
    try {
      final response = await http.get(url, headers: headers);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final content = data['content'];
        
        if (content == null) {
          print('Ошибка: Контент главы не найден в ответе API.');
          return;
        }

        final List<dynamic> pages = content['pages'] ?? [];
        if (pages.isEmpty) {
          print('Ошибка: Список страниц пуст.');
          return;
        }

        final String titleName = content['title_name'] ?? 'manga';
        final String chapterNum = content['chapter_num'] ?? chapterId;
        final directoryPath = 'downloads/${titleName.replaceAll(' ', '_')}/chapter_$chapterNum';
        
        final directory = Directory(directoryPath);
        if (!directory.existsSync()) {
          directory.createSync(recursive: true);
        }

        print('Найдено ${pages.length} страниц. Начинаю скачивание в $directoryPath...');

        for (var i = 0; i < pages.length; i++) {
          final page = pages[i];
          String imageUrl = '';
          
          if (page is List && page.isNotEmpty) {
            imageUrl = page[0]['link'] ?? '';
          } else if (page is Map) {
            imageUrl = page['link'] ?? '';
          }

          if (imageUrl.isEmpty) {
            print('Предупреждение: Не удалось найти URL для страницы ${i + 1}');
            continue;
          }

          await _downloadImage(imageUrl, directoryPath, i + 1);
        }
        
        print('\nСкачивание главы завершено!');
        print('Файлы сохранены в: ${Directory(directoryPath).absolute.path}');
      } else if (response.statusCode == 403) {
        print('Ошибка 403: Доступ запрещен. Remanga часто блокирует запросы не из СНГ.');
        print('Попробуйте запустить скрипт с использованием прокси или из региона СНГ.');
      } else {
        print('Ошибка при запросе API: ${response.statusCode}');
        print('Тело ответа: ${response.body}');
      }
    } catch (e) {
      print('Произошла ошибка: $e');
    }
  }

  Future<void> _downloadImage(String url, String dir, int pageNum) async {
    try {
      final response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        final uri = Uri.parse(url);
        final extension = uri.path.split('.').last;
        final fileName = 'page_${pageNum.toString().padLeft(3, '0')}.$extension';
        final file = File('$dir/$fileName');
        await file.writeAsBytes(response.bodyBytes);
        stdout.write('\rСохранена страница $pageNum...');
      } else {
        print('\nНе удалось скачать страницу $pageNum: ${response.statusCode}');
      }
    } catch (e) {
      print('\nОшибка при скачивании страницы $pageNum: $e');
    }
  }
}

void main(List<String> args) async {
  if (args.isEmpty) {
    print('Использование: dart bin/main.dart <chapter_id>');
    print('Пример: dart bin/main.dart 556648');
    return;
  }

  final downloader = RemangaDownloader();
  await downloader.downloadChapter(args[0]);
}
