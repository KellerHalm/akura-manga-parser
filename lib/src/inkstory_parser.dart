import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

Future<http.Response?> fetchWithRetry(String url, {int retries = 3}) async {
  for (int i = 0; i < retries; i++) {
    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(Duration(seconds: 30));
      if (response.statusCode == 200) return response;
      print('Status ${response.statusCode} для $url, повтор...');
    } catch (e) {
      print('Ошибка загрузки $url (попытка ${i + 1}/$retries): $e');
      if (i == retries - 1) rethrow;
      await Future.delayed(Duration(seconds: 2));
    }
  }
  return null;
}

Uint8List decryptXor(Uint8List data, String key) {
  final keyBytes = utf8.encode(key);
  final decrypted = Uint8List(data.length);
  for (var i = 0; i < data.length; i++) {
    decrypted[i] = data[i] ^ keyBytes[i % keyBytes.length];
  }
  return decrypted;
}

String? getEncryptionType(String url) {
  final fileName = url.split('/').last.split('.').first;
  if (fileName.length != 36) return null;
  final marker = fileName[14];
  if (marker == 's') return 'sec';
  if (marker == 'x') return 'xor';
  return null;
}

void main(List<String> arguments) async {
  HttpOverrides.global = MyHttpOverrides();

  if (arguments.isEmpty) {
    print(
      'Использование: dart inkstory_parser.dart <ссылка_на_главу_или_id> [формат: jpg|png]',
    );
    exit(1);
  }

  String input = arguments[0];
  String targetFormat = arguments.length > 1
      ? arguments[1].toLowerCase()
      : 'jpg';

  if (targetFormat != 'jpg' && targetFormat != 'png') {
    targetFormat = 'jpg';
  }

  String chapterId;
  RegExp regExp = RegExp(
    r'([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})',
  );
  Match? match = regExp.firstMatch(input);
  if (match != null) {
    chapterId = match.group(1)!;
  } else if (input.length == 36) {
    chapterId = input;
  } else {
    print('Ошибка: Не удалось найти ID главы.');
    exit(1);
  }

  final String apiUrl = 'https://api.puremanga.me/v2/chapters/$chapterId';
  final String downloadDir = 'inkstory_pages_${chapterId}_$targetFormat';

  print('Получение данных главы: $apiUrl');

  try {
    final response = await fetchWithRetry(apiUrl);

    if (response != null && response.statusCode == 200) {
      final Map<String, dynamic> jsonData = json.decode(response.body);
      final List<dynamic> pages = jsonData['pages'];

      if (pages.isEmpty) {
        print('Страницы не найдены.');
        exit(0);
      }

      final Directory dir = Directory(downloadDir);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      print('Найдено страниц: ${pages.length}. Сохранение в $targetFormat...');

      const String encryptionKey = "UySkp0BzPhwlvP2V";

      for (int i = 0; i < pages.length; i++) {
        final page = pages[i];
        String imageUrl = page['image'];
        final String fileName =
            '$downloadDir/${(i + 1).toString().padLeft(3, '0')}.$targetFormat';

        if (await File(fileName).exists()) {
          print('Страница ${i + 1} уже существует, пропуск.');
          continue;
        }

        String? encType = getEncryptionType(imageUrl);
        if (encType == 'sec') {
          List<String> parts = imageUrl.split('/');
          String last = parts.removeLast();
          last = last.substring(0, 14) + 'x' + last.substring(15);
          parts.add(last);
          imageUrl = parts.join('/');
          encType = 'xor';
        }

        print(
          'Загрузка страницы ${i + 1}/${pages.length} (${encType ?? "без шифрования"})...',
        );

        try {
          final imageResponse = await fetchWithRetry(imageUrl);
          if (imageResponse != null && imageResponse.statusCode == 200) {
            Uint8List bytes = imageResponse.bodyBytes;

            if (encType == 'xor') {
              bytes = decryptXor(bytes, encryptionKey);
            }

            final img.Image? image = img.decodeImage(bytes);

            if (image != null) {
              List<int> encodedBytes = (targetFormat == 'png')
                  ? img.encodePng(image)
                  : img.encodeJpg(image, quality: 90);

              await File(fileName).writeAsBytes(encodedBytes);
              print('Сохранено: $fileName');
            } else {
              print('Ошибка декодирования страницы ${i + 1}.');
            }
          }
        } catch (e) {
          print('Ошибка при обработке страницы ${i + 1}: $e');
        }
      }
      print('\nГотово! Папка: $downloadDir');
    }
  } catch (e) {
    print('Ошибка: $e');
  }
}
