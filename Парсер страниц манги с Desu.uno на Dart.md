# Парсер страниц манги с Desu.uno на Dart

Данный парсер предназначен для извлечения URL-адресов изображений страниц из указанной главы манги на сайте desu.uno. Он использует внутренний API сайта для получения необходимой информации.

## Как это работает

Парсер выполняет следующие шаги:

1.  **Извлечение ID манги и номера главы:** Из предоставленного URL главы манги (например, `https://desu.uno/manga/rengoku-deadroll.1400/vol1/ch1/rus`) извлекаются ID манги и номер главы.
2.  **Получение информации о манге:** Используя ID манги, парсер обращается к API `https://desu.uno/manga/api/{mangaId}` для получения общей информации о манге, включая список всех глав и их внутренние ID.
3.  **Поиск внутреннего ID главы:** На основе номера главы, извлеченного на первом шаге, парсер находит соответствующий внутренний ID главы в полученном списке.
4.  **Получение страниц главы:** С использованием ID манги и внутреннего ID главы, парсер обращается к API `https://desu.uno/manga/api/{mangaId}/chapter/{chapterInternalId}`. Этот эндпоинт возвращает список объектов, каждый из которых содержит номер страницы, ширину, высоту и самое главное — URL изображения страницы (`img`).
5.  **Формирование списка объектов MangaPage:** Полученные данные преобразуются в список объектов `MangaPage`, каждый из которых содержит номер страницы и URL изображения.

## Требования

*   Установленный Dart SDK.
*   Пакет `http` для Dart. Его можно добавить в проект с помощью команды `dart pub add http`.

## Использование

1.  Создайте новый проект Dart:
    ```bash
    mkdir desu_parser_project
    cd desu_parser_project
    dart create console
    ```
2.  Добавьте зависимость `http` в файл `pubspec.yaml`:
    ```yaml
    dependencies:
      http: ^1.1.0
    ```
    Затем выполните `dart pub get`.
3.  Замените содержимое файла `bin/desu_parser_project.dart` (или `bin/main.dart`, в зависимости от того, как вы назвали проект) на код, приведенный ниже.
4.  Запустите парсер:
    ```bash
    dart run bin/desu_parser_project.dart
    ```

## Код парсера

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Класс для представления страницы манги
class MangaPage {
  final int page;
  final String imageUrl;

  MangaPage({required this.page, required this.imageUrl});

  @override
  String toString() => 'Page $page: $imageUrl';
}

/// Парсер для сайта desu.uno
class DesuParser {
  static const String _apiBaseUrl = 'https://desu.uno/manga/api';

  /// Извлекает ID манги и ID главы из URL
  /// Пример URL: https://desu.uno/manga/rengoku-deadroll.1400/vol1/ch1/rus
  Map<String, String>? _parseUrl(String url) {
    final RegExp regExp = RegExp(r'manga\/.*\.(\d+)\/vol\d+\/ch(\d+)');
    final match = regExp.firstMatch(url);

    if (match != null && match.groupCount >= 2) {
      return {
        'mangaId': match.group(1)!,
        'chapterNum': match.group(2)!,
      };
    }
    return null;
  }

  /// Получает список страниц главы манги
  Future<List<MangaPage>> getPages(String chapterUrl) async {
    final ids = _parseUrl(chapterUrl);
    if (ids == null) {
      throw Exception('Не удалось извлечь ID из URL. Проверьте формат ссылки.');
    }

    final mangaId = ids['mangaId'];
    final chapterNum = ids['chapterNum'];

    // 1. Сначала получаем общую информацию о манге, чтобы найти внутренний ID главы
    final mangaInfoResponse = await http.get(Uri.parse('$_apiBaseUrl/$mangaId'));
    if (mangaInfoResponse.statusCode != 200) {
      throw Exception('Ошибка при получении информации о манге: ${mangaInfoResponse.statusCode}');
    }

    final mangaData = jsonDecode(mangaInfoResponse.body);
    final List chaptersList = mangaData['response']['chapters']['list'];

    // Ищем главу с нужным номером (ch)
    final chapterInfo = chaptersList.firstWhere(
      (c) => c['ch'].toString() == chapterNum,
      orElse: () => null,
    );

    if (chapterInfo == null) {
      throw Exception('Глава с номером $chapterNum не найдена.');
    }

    final chapterInternalId = chapterInfo['id'];

    // 2. Получаем страницы главы по внутреннему ID
    final chapterResponse = await http.get(Uri.parse('$_apiBaseUrl/$mangaId/chapter/$chapterInternalId'));
    if (chapterResponse.statusCode != 200) {
      throw Exception('Ошибка при получении страниц главы: ${chapterResponse.statusCode}');
    }

    final chapterData = jsonDecode(chapterResponse.body);
    final List pagesList = chapterData['response']['pages']['list'];

    return pagesList.map((p) {
      return MangaPage(
        page: p['page'] as int,
        imageUrl: p['img'] as String,
      );
    }).toList();
  }
}

void main() async {
  final parser = DesuParser();
  const url = 'https://desu.uno/manga/rengoku-deadroll.1400/vol1/ch1/rus';

  print('Начинаю парсинг: $url');
  
  try {
    final pages = await parser.getPages(url);
    print('Успешно найдено страниц: ${pages.length}\n');
    
    for (var page in pages) {
      print(page);
    }
  } catch (e) {
    print('Произошла ошибка: $e');
  }
}
```

## Пример вывода

```
Начинаю парсинг: https://desu.uno/manga/rengoku-deadroll.1400/vol1/ch1/rus
Успешно найдено страниц: 59

Page 1: https://img4.desu.uno/manga/rus/rengoku_deadroll/vol01_ch001/rengoku_deadroll_vol01_ch001_p001.jpg?1534464000
Page 2: https://img4.desu.uno/manga/rus/rengoku_deadroll/vol01_ch001/rengoku_deadroll_vol01_ch001_p002.jpg?1534464000
Page 3: https://img4.desu.uno/manga/rus/rengoku_deadroll/vol01_ch001/rengoku_deadroll_vol01_ch001_p003.jpg?1534464000
Page 4: https://img4.desu.uno/manga/rus/rengoku_deadroll/vol01_ch001/rengoku_deadroll_vol01_ch001_p004.jpg?1534464000
Page 5: https://img4.desu.uno/manga/rus/rengoku_deadroll/vol01_ch001/rengoku_deadroll_vol01_ch001_p005.jpg?1534464000
Page 6: https://img4.desu.uno/manga/rus/rengoku_deadroll/vol01_ch001/rengoku_deadroll_vol01_ch001_p006.png?1534464000
Page 7: https://img4.desu.uno/manga/rus/rengoku_deadroll/vol01_ch001/rengoku_deadroll_vol01_ch001_p007.png?1534464000
Page 8: https://img4.desu.uno/manga/rus/rengoku_deadroll/vol01_ch001/rengoku_deadroll_vol01_ch001_p008.png?1534464000
Page 9: https://img4.desu.uno/manga/rus/rengoku_deadroll/vol01_ch001/rengoku_deadroll_vol01_ch001_p009.png?1534464000
Page 10: https://img4.desu.uno/manga/rus/rengoku_deadroll/vol01_ch001/rengoku_deadroll_vol01_ch001_p010.png?1534464000
Page 11: https://img4.desu.uno/manga/rus/rengoku_deadroll/vol01_ch001/rengoku_deadroll_vol01_ch001_p011.png?1534464000
Page 12: https://img4.desu.uno/manga/rus/rengoku_deadroll/vol01_ch001/rengoku_deadroll_vol01_ch001_p012.png?1534464000
Page 13: https://img4.desu.uno/manga/rus/rengoku_deadroll/vol01_ch001/rengoku_deadroll_vol01_ch001_p013.png?1534464000
Page 14: https://img4.desu.uno/manga/rus/rengoku_deadroll/vol01_ch001/rengoku_deadroll_vol01_ch001_p014.png?1534464000
Page 15: https://img4.desu.uno/manga/rus/rengoku_deadroll/vol01_ch001/rengoku_deadroll_vol01_ch001_p015.png?1534464000
Page 16: https://img4.desu.uno/manga/rus/rengoku_deadroll/vol01_ch001/rengoku_deadroll_vol01_ch001_p016.png?1534464000
Page 17: https://img4.desu.uno/manga/rus/rengoku_deadroll/vol01_ch001/rengoku_deadroll_vol01_ch001_p017.png?1534464000
Page 18: https://img4.desu.uno/manga/rus/rengoku_deadroll/vol01_ch001/rengoku_deadroll_vol01_ch001_p018.png?1534464000
Page 19: https://img4.desu.uno/manga/rus/rengoku_deadroll/vol01_ch001/rengoku_deadroll_vol01_ch001_p019.png?1534464000
Page 20: https://img4.desu.uno/manga/rus/rengoku_deadroll/vol01_ch001/rengoku_deadroll_vol01_ch001_p020.png?1534464000
Page 21: https://img4.desu.uno/manga/rus/rengoku_deadroll/vol01_ch001/rengoku_deadroll_vol01_ch001_p021.png?1534464000
Page 22: https://img4.desu.uno/manga/rus/rengoku_deadroll/vol01_ch001/rengoku_deadroll_vol01_ch001_p022.png?1534464000
Page 23: https://img4.desu.uno/manga/rus/rengoku_deadroll/vol01_ch001/rengoku_deadroll_vol01_ch001_p023.png?1534464000
Page 24: https://img4.desu.uno/manga/rus/rengoku_deadroll/vol01_ch001/rengoku_deadroll_vol01_ch001_p024.png?1534464000
Page 25: https://img4.desu.uno/manga/rus/rengoku_deadroll/vol01_ch001/rengoku_deadroll_vol01_ch001_p025.png?1534464000
Page 26: https://img4.desu.uno/manga/rus/rengoku_deadroll/vol01_ch001/rengoku_deadroll_vol01_ch001_p026.png?1534464000
Page 27: https://img4.desu.uno/manga/rus/rengoku_deadroll/vol01_ch001/rengoku_deadroll_vol01_ch001_p027.png?1534464000
Page 28: https://img4.desu.uno/manga/rus/rengoku_deadroll/vol01_ch001/rengoku_deadroll_vol01_ch001_p028.png?1534464000
Page 29: https://img4.desu.uno/manga/rus/rengoku_deadroll/vol01_ch001/rengoku_deadroll_vol01_ch001_p029.png?1534464000
Page 30: https://img4.desu.uno/manga/rus/rengoku_deadroll/vol01_ch001/rengoku_deadroll_vol01_ch001_p030.png?1534464000
Page 31: https://img4.desu.uno/manga/rus/rengoku_deadroll/vol01_ch001/rengoku_deadroll_vol01_ch001_p031.png?1534464000
Page 32: https://img4.desu.uno/manga/rus/rengoku_deadroll/vol01_ch001/rengoku_deadroll_vol01_ch001_p032.png?1534464000
Page 33: https://img4.desu.uno/manga/rus/rengoku_deadroll/vol01_ch001/rengoku_deadroll_vol01_ch001_p033.png?1534464000
Page 34: https://img4.desu.uno/manga/rus/rengoku_deadroll/vol01_ch001/rengoku_deadroll_vol01_ch001_p034.png?1534464000
Page 35: https://img4.desu.uno/manga/rus/rengoku_deadroll/vol01_ch001/rengoku_deadroll_vol01_ch001_p035.png?1534464000
Page 36: https://img4.desu.uno/manga/rus/rengoku_deadroll/vol01_ch001/rengoku_deadroll_vol01_ch001_p036.png?1534464000
Page 37: https://img4.desu.uno/manga/rus/rengoku_deadroll/vol01_ch001/rengoku_deadroll_vol01_ch001_p037.jpg?1534464000
Page 38: https://img4.desu.uno/manga/rus/rengoku_deadroll/vol01_ch001/rengoku_deadroll_vol01_ch001_p038.png?1534464000
Page 39: https://img4.desu.uno/manga/rus/rengoku_deadroll/vol01_ch001/rengoku_deadroll_vol01_ch001_p039.png?1534464000
Page 40: https://img4.desu.uno/manga/rus/rengoku_deadroll/vol01_ch001/rengoku_deadroll_vol01_ch001_p040.png?1534464000
Page 41: https://img4.desu.uno/manga/rus/rengoku_deadroll/vol01_ch001/rengoku_deadroll_vol01_ch001_p041.png?1534464000
Page 42: https://img4.desu.uno/manga/rus/rengoku_deadroll/vol01_ch001/rengoku_deadroll_vol01_ch001_p042.png?1534464000
Page 43: https://img4.desu.uno/manga/rus/rengoku_deadroll/vol01_ch001/rengoku_deadroll_vol01_ch001_p043.png?1534464000
Page 44: https://img4.desu.uno/manga/rus/rengoku_deadroll/vol01_ch001/rengoku_deadroll_vol01_ch001_p044.png?1534464000
Page 45: https://img4.desu.uno/manga/rus/rengoku_deadroll/vol01_ch001/rengoku_deadroll_vol01_ch001_p045.png?1534464000
Page 46: https://img4.desu.uno/manga/rus/rengoku_deadroll/vol01_ch001/rengoku_deadroll_vol01_ch001_p046.png?1534464000
Page 47: https://img4.desu.uno/manga/rus/rengoku_deadroll/vol01_ch001/rengoku_deadroll_vol01_ch001_p047.png?1534464000
Page 48: https://img4.desu.uno/manga/rus/rengoku_deadroll/vol01_ch001/rengoku_deadroll_vol01_ch001_p048.png?1534464000
Page 49: https://img4.desu.uno/manga/rus/rengoku_deadroll/vol01_ch001/rengoku_deadroll_vol01_ch001_p049.png?1534464000
Page 50: https://img4.desu.uno/manga/rus/rengoku_deadroll/vol01_ch001/rengoku_deadroll_vol01_ch001_p050.png?1534464000
Page 51: https://img4.desu.uno/manga/rus/rengoku_deadroll/vol01_ch001/rengoku_deadroll_vol01_ch001_p051.png?1534464000
Page 52: https://img4.desu.uno/manga/rus/rengoku_deadroll/vol01_ch001/rengoku_deadroll_vol01_ch001_p052.png?1534464000
Page 53: https://img4.desu.uno/manga/rus/rengoku_deadroll/vol01_ch001/rengoku_deadroll_vol01_ch001_p053.png?1534464000
Page 54: https://img4.desu.uno/manga/rus/rengoku_deadroll/vol01_ch001/rengoku_deadroll_vol01_ch001_p054.png?1534464000
Page 55: https://img4.desu.uno/manga/rus/rengoku_deadroll/vol01_ch001/rengoku_deadroll_vol01_ch001_p055.png?1534464000
Page 56: https://img4.desu.uno/manga/rus/rengoku_deadroll/vol01_ch001/rengoku_deadroll_vol01_ch001_p056.png?1534464000
Page 57: https://img4.desu.uno/manga/rus/rengoku_deadroll/vol01_ch001/rengoku_deadroll_vol01_ch001_p057.png?1534464000
Page 58: https://img4.desu.uno/manga/rus/rengoku_deadroll/vol01_ch001/rengoku_deadroll_vol01_ch001_p058.png?1534464000
Page 59: https://img4.desu.uno/manga/rus/rengoku_deadroll/vol01_ch001/rengoku_deadroll_vol01_ch001_p059.jpg?1534464000
```
