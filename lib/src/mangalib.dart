import 'package:puppeteer/puppeteer.dart';
import 'dart:convert';

void main() async {
  final String url = 'https://mangalib.org/ru/manga/127--hunter_x_hunter';
  print('Запуск браузера для парсинга: $url...');

  // 1. Запуск headless-браузера
  final browser = await puppeteer.launch(headless: true);
  final page = await browser.newPage();

  // Устанавливаем реалистичный User-Agent
  await page.setUserAgent(
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
  );

  try {
    // 2. Переход на страницу
    await page.goto(url, wait: Until.networkIdle);

    // 3. Извлечение JSON-LD блока через JavaScript в контексте страницы
    final String? jsonLdRaw = await page.evaluate<String?>(r'''() => {
      const script = document.querySelector('script[type="application/ld+json"]');
      return script ? script.innerText : null;
    }''');

    if (jsonLdRaw != null) {
      final List<dynamic> jsonData = jsonDecode(jsonLdRaw);
      final mangaData = jsonData.firstWhere(
        (item) => item['@type'] == 'CreativeWorkSeries',
        orElse: () => null,
      );

      if (mangaData != null) {
        print('\n=== ДАННЫЕ ИЗВЛЕЧЕНЫ УСПЕШНО ===');
        print('Название: ${mangaData['name']}');
        print('Жанры: ${mangaData['genre']}');
        print('Рейтинг: ${mangaData['aggregateRating']['ratingValue']}');
        print('Описание: ${mangaData['description']}');
      }
    } else {
      print(
        'Не удалось найти JSON-LD. Возможно, страница не загрузилась полностью.',
      );
    }

    // 4. Извлечение глав (они подгружаются через JS)
    print('\nЗагрузка списка глав...');
    final chapters = await page.evaluate(r'''() => {
      return Array.from(document.querySelectorAll('a.chapter-item__name')).map(a => ({
        name: a.innerText.trim(),
        url: a.href
      }));
    }''');

    print('Найдено глав: ${chapters.length}');
    for (var i = 0; i < (chapters.length > 5 ? 5 : chapters.length); i++) {
      print('- ${chapters[i]['name']}');
    }
  } catch (e) {
    print('Произошла ошибка: $e');
  } finally {
    await browser.close();
  }
}
