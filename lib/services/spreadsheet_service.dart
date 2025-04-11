import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:csv/csv.dart';
import '../models/vocabulary_item.dart';

/// スプレッドシート関連の処理を提供するサービス
class SpreadsheetService {
  // スプレッドシートの共有リンクからシートIDを抽出
  static String? extractSheetId(String url) {
    final RegExp regex = RegExp(r"/d/([a-zA-Z0-9-_]+)");
    final match = regex.firstMatch(url);
    return match != null ? match.group(1) : null;
  }
  
  // シートIDからCSVデータを取得
  static Future<List<List<dynamic>>> fetchCsvData(String sheetId) async {
    final csvUrl = "https://docs.google.com/spreadsheets/d/$sheetId/export?format=csv&gid=0";
    
    final response = await http.get(Uri.parse(csvUrl));
    if (response.statusCode != 200) {
      throw Exception("データの取得に失敗しました。HTTPステータスコード: ${response.statusCode}");
    }
    
    // UTF-8でレスポンスのバイトデータをデコード
    final csvContent = utf8.decode(response.bodyBytes);
    
    // CSVパース
    return const CsvToListConverter().convert(csvContent);
  }
  
  // CSVデータから必要なヘッダーのインデックスを取得
  static Map<String, int> getHeaderIndices(List<dynamic> header) {
    final requiredColumns = ["単語", "意味", "備考", "カテゴリー", "緑", "黄", "赤"];
    final Map<String, int> indices = {};
    
    for (final column in requiredColumns) {
      final index = header.indexOf(column);
      if (index == -1) {
        throw Exception("CSVに必要なカラム「$column」が見つかりません。");
      }
      indices[column] = index;
    }
    
    return indices;
  }
  
  // CSVデータから単語リストを作成
  static List<VocabularyItem> createVocabularyItems(List<List<dynamic>> csvData) {
    if (csvData.isEmpty) {
      throw Exception("CSVデータが空です。");
    }
    
    final headerIndices = getHeaderIndices(csvData[0]);
    final List<VocabularyItem> items = [];
    
    for (var i = 1; i < csvData.length; i++) {
      final row = csvData[i];
      if (row.length > headerIndices.values.reduce((a, b) => a > b ? a : b)) {
        items.add(VocabularyItem.fromCsvRow(row, headerIndices));
      }
    }
    
    if (items.isEmpty) {
      throw Exception("単語データが見つかりません。");
    }
    
    return items;
  }
}
