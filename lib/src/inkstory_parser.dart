import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

Future<http.Response?> fetchWithRetry(String url, {int retries = 3}) async {
  for (int i = 0; i < retries; i++) {
    try {
      final response = await http.get(Uri.parse(url)).timeout(Duration(seconds: 30));
      if (response.statusCode == 200) return response;
      print('Status ${response.statusCode} for $url, retrying...');
    } catch (e) {
      print('Error fetching $url (attempt ${i + 1}/$retries): $e');
      if (i == retries - 1) rethrow;
      await Future.delayed(Duration(seconds: 2));
    }
  }
  return null;
}

void main(List<String> arguments) async {
  if (arguments.isEmpty) {
    print('Usage: dart manga_parser.dart <chapter_url_or_id>');
    exit(1);
  }

  String input = arguments[0];
  String chapterId;

  if (input.startsWith('http')) {
    RegExp regExp = RegExp(r'([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})');
    Match? match = regExp.firstMatch(input);
    if (match != null) {
      chapterId = match.group(1)!;
    } else {
      print('Invalid chapter URL provided.');
      exit(1);
    }
  } else {
    chapterId = input;
  }

  final String apiUrl = 'https://api.puremanga.me/v2/chapters/$chapterId';
  final String downloadDir = 'manga_pages_$chapterId';

  print('Fetching chapter data from: $apiUrl');

  try {
    final response = await fetchWithRetry(apiUrl);

    if (response != null && response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      final List<dynamic> pages = data['pages'];

      if (pages.isEmpty) {
        print('No pages found for this chapter.');
        exit(0);
      }

      final Directory dir = Directory(downloadDir);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      print('Downloading ${pages.length} pages to $downloadDir...');

      for (int i = 0; i < pages.length; i++) {
        final page = pages[i];
        final String imageUrl = page['image'];
        final String extension = imageUrl.split('.').last.split('?').first;
        final String fileName = '$downloadDir/${i.toString().padLeft(3, '0')}.$extension';

        if (await File(fileName).exists()) {
          print('Page ${i + 1} already exists, skipping.');
          continue;
        }

        print('Downloading page ${i + 1}/${pages.length}: $imageUrl');
        try {
          final imageResponse = await fetchWithRetry(imageUrl);
          if (imageResponse != null && imageResponse.statusCode == 200) {
            final File file = File(fileName);
            await file.writeAsBytes(imageResponse.bodyBytes);
            print('Saved: $fileName');
          }
        } catch (e) {
          print('Failed to download page ${i + 1} after retries.');
        }
      }
      print('Download process finished!');
    } else {
      print('Failed to fetch chapter data.');
    }
  } catch (e) {
    print('An error occurred: $e');
  }
}
