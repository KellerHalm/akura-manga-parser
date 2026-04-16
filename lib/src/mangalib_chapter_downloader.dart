import 'dart:io';
import 'dart:convert';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    print('Usage: dart mangalib_chapter_downloader.dart <chapter_url>');
    return;
  }

  final String originalUrl = args[0];
  print('--- MangaLib Chapter Downloader ---');
  print('Target URL: $originalUrl');

  final uri = Uri.parse(originalUrl);
  final pathSegments = uri.pathSegments;
  
  String? mangaSlug;
  String volume = '1';
  String number = '1';
  String? branchId;

  try {
    mangaSlug = pathSegments[1]; 
    volume = pathSegments[pathSegments.indexOf('read') + 1].replaceFirst('v', '');
    number = pathSegments[pathSegments.indexOf('read') + 2].replaceFirst('c', '');
    branchId = uri.queryParameters['bid'];
  } catch (e) {
    print('Error parsing URL segments. Please ensure the URL is a valid MangaLib chapter link.');
    return;
  }

  if (branchId == null) {
    print('Warning: bid (branch_id) not found in URL. Attempting to fetch without it...');
  }

  final apiUrl = 'https://api.cdnlibs.org/api/manga/$mangaSlug/chapter?number=$number&volume=$volume${branchId != null ? "&branch_id=$branchId" : ""}';
  print('API URL: $apiUrl');

  final directory = Directory('mangalib_pages');
  if (!await directory.exists()) {
    await directory.create();
  }

  print('Fetching chapter data from API...');
  
  final result = await Process.run('curl', [
    '-s',
    '-H', 'User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    '-H', 'Referer: https://mangalib.org/',
    '-L',
    apiUrl
  ]);

  if (result.exitCode != 0) {
    print('Error fetching API: ${result.stderr}');
    return;
  }

  final responseBody = result.stdout as String;
  
  try {
    final data = json.decode(responseBody);
    final chapterData = data['data'];
    final pages = chapterData['pages'] as List<dynamic>;
    
    print('Found ${pages.length} pages. Starting download...');

    const String imageServer = 'https://img3.mixlib.me';

    for (var i = 0; i < pages.length; i++) {
      final page = pages[i];
      final imgUrlPart = page['url'] as String;
      final fullImgUrl = '$imageServer$imgUrlPart';
      
      final fileName = 'page_${(i + 1).toString().padLeft(3, '0')}.png';
      final filePath = '${directory.path}/$fileName';

      print('[${i + 1}/${pages.length}] Downloading $fileName...');
      
      final dlResult = await Process.run('curl', [
        '-s',
        '-H', 'User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        '-H', 'Referer: https://mangalib.org/',
        '-o', filePath,
        '-L',
        fullImgUrl
      ]);

      if (dlResult.exitCode != 0) {
        print('Failed to download page ${i + 1}');
      }
    }

    print('\nSUCCESS: All pages saved in ${directory.path}/ directory.');
  } catch (e) {
    print('Error parsing API response: $e');
    print('API Response was: ${responseBody.length > 500 ? responseBody.substring(0, 500) + "..." : responseBody}');
  }
}
