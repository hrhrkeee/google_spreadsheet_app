import 'dart:convert';
import 'dart:html' as html;
import '../models/app_settings.dart';
import '../models/sheet_history.dart';

/// ローカルストレージ関連の処理を提供するサービス
class StorageService {
  static const String _historyKey = "sheet_history";
  static const String _settingsKey = "app_settings";
  
  // 履歴の保存
  static void saveHistory(List<SheetHistory> history) {
    final jsonStr = jsonEncode(history.map((h) => h.toMap()).toList());
    html.window.localStorage[_historyKey] = jsonStr;
  }
  
  // 履歴の読み込み
  static List<SheetHistory> loadHistory() {
    final jsonStr = html.window.localStorage[_historyKey];
    if (jsonStr == null) return [];
    
    try {
      final List<dynamic> list = jsonDecode(jsonStr);
      return list.map((item) => SheetHistory.fromMap(item)).toList();
    } catch (e) {
      return [];
    }
  }
  
  // 設定の保存
  static void saveSettings(AppSettings settings) {
    final jsonStr = jsonEncode(settings.toMap());
    html.window.localStorage[_settingsKey] = jsonStr;
  }
  
  // 設定の読み込み
  static AppSettings loadSettings() {
    final jsonStr = html.window.localStorage[_settingsKey];
    if (jsonStr == null) return AppSettings();
    
    try {
      final Map<String, dynamic> map = jsonDecode(jsonStr);
      return AppSettings.fromMap(map);
    } catch (e) {
      return AppSettings();
    }
  }
}
