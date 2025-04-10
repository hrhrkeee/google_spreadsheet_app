import 'dart:convert';
import 'dart:html' as html; // localStorage 利用のため
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Clipboardへのアクセスのため追加
import 'package:http/http.dart' as http;
import 'package:csv/csv.dart';

void main() {
  runApp(MyApp());
}

/// アプリ全体のルートウィジェット
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '単語帳アプリ',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: SpreadsheetPage(),
    );
  }
}

// 設定を管理するクラスを追加
class AppSettings {
  // デフォルト値
  static const double DEFAULT_TEXT_SIZE = 24.0;  // 単語と意味の共通サイズ
  static const double DEFAULT_NOTES_SIZE = 16.0;
  
  // 単語カード内の文字サイズ
  double textSize;  // 単語と意味の共通サイズ（統一）
  double notesSize;

  // コンストラクタ（デフォルト値を設定）
  AppSettings({
    this.textSize = DEFAULT_TEXT_SIZE,
    this.notesSize = DEFAULT_NOTES_SIZE,
  });

  // JSONに変換するメソッド
  Map<String, dynamic> toMap() {
    return {
      'textSize': textSize,
      'notesSize': notesSize,
    };
  }

  // JSONから復元するファクトリメソッド
  factory AppSettings.fromMap(Map<String, dynamic> map) {
    // 後方互換性のための処理（既存データを新しい形式に変換）
    if (map.containsKey('wordSize') && map.containsKey('meaningSize')) {
      // 以前の設定があれば、wordSizeを優先して使用
      final textSize = map['wordSize'] ?? DEFAULT_TEXT_SIZE;
      return AppSettings(
        textSize: textSize,
        notesSize: map['notesSize'] ?? DEFAULT_NOTES_SIZE,
      );
    }
    
    // 新しい形式の場合
    return AppSettings(
      textSize: map['textSize'] ?? DEFAULT_TEXT_SIZE,
      notesSize: map['notesSize'] ?? DEFAULT_NOTES_SIZE,
    );
  }
}

// 単語データを保持するモデルクラス（カテゴリーと色フラグ付き）
class VocabularyItem {
  final String word; // 単語
  final String meaning; // 意味
  final String notes; // 備考
  final String category; // カテゴリー
  final bool green; // 緑フラグ
  final bool yellow; // 黄フラグ
  final bool red; // 赤フラグ

  VocabularyItem({
    required this.word,
    required this.meaning,
    required this.notes,
    required this.category,
    required this.green,
    required this.yellow,
    required this.red,
  });

  Map<String, dynamic> toMap() {
    return {
      'word': word,
      'meaning': meaning,
      'notes': notes,
      'category': category,
      'green': green,
      'yellow': yellow,
      'red': red,
    };
  }

  factory VocabularyItem.fromMap(Map<String, dynamic> map) {
    return VocabularyItem(
      word: map['word'],
      meaning: map['meaning'],
      notes: map['notes'],
      category: map['category'],
      green: map['green'],
      yellow: map['yellow'],
      red: map['red'],
    );
  }
}

/// シートの履歴を保持するクラス 
class SheetHistory {
  final String sheetId; // シートID
  String displayName; // 表示名（編集可能）
  final DateTime retrievalDate;
  bool isFavorite; // お気に入りフラグを追加

  SheetHistory({
    required this.sheetId,
    String? displayName, // オプショナルに
    required this.retrievalDate,
    this.isFavorite = false, // デフォルトはfalse
  }) : displayName = displayName ?? sheetId; // デフォルトはsheetId

  Map<String, dynamic> toMap() {
    return {
      'sheetId': sheetId,
      'displayName': displayName,
      'retrievalDate': retrievalDate.toIso8601String(),
      'isFavorite': isFavorite, // お気に入り情報を保存
    };
  }

  factory SheetHistory.fromMap(Map<String, dynamic> map) {
    return SheetHistory(
      sheetId: map['sheetId'],
      displayName: map['displayName'] ?? map['sheetId'], // 後方互換性のため
      retrievalDate: DateTime.parse(map['retrievalDate']),
      isFavorite: map['isFavorite'] ?? false, // 後方互換性のため
    );
  }
}

/// 設定画面
class SettingsPage extends StatefulWidget {
  final AppSettings settings;
  final Function(AppSettings) onSettingsChanged;

  SettingsPage({required this.settings, required this.onSettingsChanged});

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late double _textSize;  // 単語と意味の共通サイズ
  late double _notesSize;
  bool _hasChanges = false; // 設定変更の有無を追跡

  @override
  void initState() {
    super.initState();
    // 現在の設定値を取得
    _textSize = widget.settings.textSize;
    _notesSize = widget.settings.notesSize;
  }

  // 設定を保存する
  void _saveSettings() {
    final newSettings = AppSettings(
      textSize: _textSize,
      notesSize: _notesSize,
    );
    widget.onSettingsChanged(newSettings);
    Navigator.pop(context);
  }
  
  // 変更の確認ダイアログを表示
  Future<bool?> _showConfirmationDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('設定の保存'),
        content: Text('変更した設定を保存しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false), // いいえ
            child: Text('いいえ'),
          ),
          ElevatedButton(
            onPressed: () {
              _saveSettings();
              Navigator.of(context).pop(true); // はい
            },
            child: Text('はい'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // 変更があった場合のみダイアログを表示
        if (_hasChanges) {
          final result = await _showConfirmationDialog();
          return result == null || result == false;
        }
        return true; // 変更がなければそのまま戻る
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('設定'),
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () {
              if (_hasChanges) {
                _showConfirmationDialog();
              } else {
                Navigator.of(context).pop();
              }
            },
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.save),
              onPressed: _saveSettings,
              tooltip: '設定を保存',
            ),
          ],
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '単語カードの文字サイズ',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 16),
                        
                        // 単語と意味の共通文字サイズ
                        Text('単語と意味のサイズ: ${_textSize.toStringAsFixed(1)}'),
                        Slider(
                          value: _textSize,
                          min: 16.0,
                          max: 40.0,
                          divisions: 24,
                          label: _textSize.toStringAsFixed(1),
                          onChanged: (value) {
                            setState(() {
                              _textSize = value;
                              _hasChanges = _textSize != widget.settings.textSize || 
                                           _notesSize != widget.settings.notesSize;
                            });
                          },
                        ),
                        
                        SizedBox(height: 16),
                        
                        // 備考の文字サイズ
                        Text('備考のサイズ: ${_notesSize.toStringAsFixed(1)}'),
                        Slider(
                          value: _notesSize,
                          min: 12.0,
                          max: 24.0,
                          divisions: 12,
                          label: _notesSize.toStringAsFixed(1),
                          onChanged: (value) {
                            setState(() {
                              _notesSize = value;
                              _hasChanges = _textSize != widget.settings.textSize || 
                                           _notesSize != widget.settings.notesSize;
                            });
                          },
                        ),
                        
                        SizedBox(height: 16),
                        
                        // サンプルテキスト表示
                        Text('プレビュー：'),
                        SizedBox(height: 8),
                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('単語サンプル', style: TextStyle(fontSize: _textSize)),
                              Divider(),
                              Text('意味サンプル', style: TextStyle(fontSize: _textSize)),
                              SizedBox(height: 4),
                              Text('備考サンプル', style: TextStyle(fontSize: _notesSize)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Googleスプレッドシートの共有リンクからCSVデータを取得する画面
class SpreadsheetPage extends StatefulWidget {
  @override
  _SpreadsheetPageState createState() => _SpreadsheetPageState();
}

class _SpreadsheetPageState extends State<SpreadsheetPage> {
  final TextEditingController _linkController = TextEditingController();
  bool _loading = false;
  String? _errorMessage;
  List<List<dynamic>>? _csvData;
  List<VocabularyItem>? _vocabularyItems;
  List<VocabularyItem>? _allVocabularyItems;
  bool _linkHasText = false; // テキスト入力の状態を追跡する変数を追加

  // 色フィルター用チェックボックス状態
  bool _filterGreen = false;
  bool _filterYellow = false;
  bool _filterRed = false;

  // 履歴リスト（localStorage を利用して永続化）
  final List<SheetHistory> _history = [];
  final String _storageKey = "sheet_history";

  // 追加：アプリ設定
  AppSettings _appSettings = AppSettings();
  final String _settingsStorageKey = "app_settings";

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _loadSettings(); // 設定の読み込みを追加
    
    // テキスト入力の変更を検知するリスナーを追加
    _linkController.addListener(() {
      final hasText = _linkController.text.isNotEmpty;
      if (hasText != _linkHasText) {
        setState(() {
          _linkHasText = hasText;
          // 入力が空になった場合はエラーメッセージをクリア
          if (!hasText) {
            _errorMessage = null;
          }
        });
      }
    });
  }

  // 追加：設定を保存する関数
  void _saveSettings() {
    String jsonStr = jsonEncode(_appSettings.toMap());
    html.window.localStorage[_settingsStorageKey] = jsonStr;
  }
  
  // 追加：設定を読み込む関数
  void _loadSettings() {
    String? jsonStr = html.window.localStorage[_settingsStorageKey];
    if (jsonStr != null) {
      try {
        Map<String, dynamic> map = jsonDecode(jsonStr);
        setState(() {
          _appSettings = AppSettings.fromMap(map);
        });
      } catch (e) {
        // 読み込みに失敗した場合はデフォルト設定を使用
        setState(() {
          _appSettings = AppSettings();
        });
      }
    }
  }
  
  // 追加：設定を更新する関数
  void _updateSettings(AppSettings newSettings) {
    setState(() {
      _appSettings = newSettings;
      _saveSettings(); // 設定を保存
    });
  }
  
  @override
  void dispose() {
    // コントローラーを破棄
    _linkController.dispose();
    super.dispose();
  }

  // 追加：フィルターを適用する関数
  void _applyFilters() {
    if (_allVocabularyItems == null || _allVocabularyItems!.isEmpty) {
      return; // データがまだ読み込まれていない場合は何もしない
    }

    setState(() {
      bool anyFilterActive = _filterGreen || _filterYellow || _filterRed;

      if (!anyFilterActive) {
        // フィルターが選択されていない場合は全データを表示
        _vocabularyItems = _allVocabularyItems;
        _errorMessage = null;
        return;
      }

      // フィルターに基づいて単語を絞り込み
      List<VocabularyItem> filtered =
          _allVocabularyItems!.where((item) {
            return (_filterGreen && item.green) ||
                (_filterYellow && item.yellow) ||
                (_filterRed && item.red);
          }).toList();

      if (filtered.isEmpty) {
        // エラーメッセージを表示せず、代わりにすべての単語を表示
        _vocabularyItems = _allVocabularyItems;
        
        // ユーザーに通知
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("選択した条件に一致する単語がありません。すべての単語を表示します。"),
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        _errorMessage = null;
        _vocabularyItems = filtered;
      }
    });
  }

  // 重複するinitStateメソッドを削除しました

  /// localStorage に履歴を保存する関数
  void _saveHistory() {
    List<Map<String, dynamic>> historyMapList =
        _history.map((h) => h.toMap()).toList();
    String jsonStr = jsonEncode(historyMapList);
    html.window.localStorage[_storageKey] = jsonStr;
  }

  /// localStorage から履歴を読み込む関数
  void _loadHistory() {
    String? jsonStr = html.window.localStorage[_storageKey];
    if (jsonStr != null) {
      try {
        List<dynamic> list = jsonDecode(jsonStr);
        List<SheetHistory> loadedHistory =
            list.map((item) => SheetHistory.fromMap(item)).toList();
        setState(() {
          _history.clear();
          _history.addAll(loadedHistory);
        });
      } catch (e) {
        // 読み込みに失敗した場合は履歴を初期化
        setState(() {
          _history.clear();
        });
      }
    }
  }

  /// スプレッドシートの共有リンクからシートIDを抽出する関数
  String? _extractSheetId(String url) {
    final RegExp regex = RegExp(r"/d/([a-zA-Z0-9-_]+)");
    final match = regex.firstMatch(url);
    return match != null ? match.group(1) : null;
  }

  /// クリップボードからリンクを貼り付け
  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data != null && data.text != null) {
      setState(() {
        _linkController.text = data.text!;
      });
    }
  }

  /// スプレッドシートを取得してフラッシュカードを開始する統合関数
  Future<void> _fetchAndStartFlashcards() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
      _csvData = null;
      _vocabularyItems = null;
    });

    String link = _linkController.text.trim();
    if (link.isEmpty) {
      setState(() {
        _errorMessage = "リンクが空です。";
        _loading = false;
      });
      return;
    }

    // シートIDの抽出
    final sheetId = _extractSheetId(link);
    if (sheetId == null) {
      setState(() {
        _errorMessage = "無効なGoogleスプレッドシートのリンクです。";
        _loading = false;
      });
      return;
    }

    // CSV取得用 URL を生成
    final csvUrl =
        "https://docs.google.com/spreadsheets/d/$sheetId/export?format=csv&gid=0";

    try {
      final response = await http.get(Uri.parse(csvUrl));
      if (response.statusCode != 200) {
        setState(() {
          _errorMessage = "データの取得に失敗しました。HTTPステータスコード: ${response.statusCode}";
          _loading = false;
        });
        return;
      }

      // シート名はシートIDを利用（必要に応じて変更可能）
      String sheetName = sheetId;

      // UTF-8でレスポンスのバイトデータをデコード
      final csvContent = utf8.decode(response.bodyBytes);

      // CSVパース（csvパッケージを利用）
      final csvTable = const CsvToListConverter().convert(csvContent);

      setState(() {
        _csvData = csvTable;
      });

      // CSVの1行目をヘッダーとして、必要なカラムの存在を確認
      if (_csvData != null && _csvData!.isNotEmpty) {
        final header = _csvData![0];
        final int wordIndex = header.indexOf("単語");
        final int meaningIndex = header.indexOf("意味");
        final int notesIndex = header.indexOf("備考");
        final int categoryIndex = header.indexOf("カテゴリー");
        final int greenIndex = header.indexOf("緑");
        final int yellowIndex = header.indexOf("黄");
        final int redIndex = header.indexOf("赤");

        if (wordIndex == -1 ||
            meaningIndex == -1 ||
            notesIndex == -1 ||
            categoryIndex == -1 ||
            greenIndex == -1 ||
            yellowIndex == -1 ||
            redIndex == -1) {
          setState(() {
            _errorMessage = "CSVに必要なカラム（単語、意味、備考、カテゴリー、緑、黄、赤）が見つかりません。";
            _loading = false;
          });
          return;
        }

        // ヘッダー以降の各行から VocabularyItem を生成
        List<VocabularyItem> allItems = [];
        for (var i = 1; i < _csvData!.length; i++) {
          var row = _csvData![i];
          if (row.length > redIndex) {
            allItems.add(
              VocabularyItem(
                word: row[wordIndex].toString(),
                meaning: row[meaningIndex].toString(),
                notes: row[notesIndex].toString(),
                category: row[categoryIndex].toString(),
                green: row[greenIndex].toString().toLowerCase() == 'true',
                yellow: row[yellowIndex].toString().toLowerCase() == 'true',
                red: row[redIndex].toString().toLowerCase() == 'true',
              ),
            );
          }
        }

        if (allItems.isEmpty) {
          setState(() {
            _errorMessage = "単語データが存在しません。";
            _loading = false;
          });
          return;
        }

        // 全データを保存
        _allVocabularyItems = allItems;

        // チェックボックスの状態に基づいてフィルタリング
        bool anyFilterActive = _filterGreen || _filterYellow || _filterRed;

        List<VocabularyItem> itemsToUse = allItems;
        
        if (anyFilterActive) {
          List<VocabularyItem> filteredItems =
              allItems.where((item) {
                // いずれかの選択された色フラグがtrueの単語を含める
                return (_filterGreen && item.green) ||
                    (_filterYellow && item.yellow) ||
                    (_filterRed && item.red);
              }).toList();

          // フィルタリングして0件の場合の処理（修正部分）
          if (filteredItems.isEmpty) {
            // エラーメッセージを表示せず、代わりにSnackBarで通知
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("選択した条件に一致する単語がありません。すべての単語を表示します。"),
                duration: Duration(seconds: 3),
              ),
            );
            // itemsToUseはそのままallItems（全単語）を使用（何も変更しない）
          } else {
            itemsToUse = filteredItems;
          }
        } 

        // 履歴へ追加（取得時刻は現在日時）
        SheetHistory newHistory = SheetHistory(
          sheetId: sheetId, 
          displayName: sheetName, // 初期表示名はシートIDと同じ
          retrievalDate: DateTime.now(),
        );
        
        setState(() {
          _vocabularyItems = itemsToUse;
          _history.add(newHistory);
          _loading = false;
        });
        
        _saveHistory();
        
        // 単語帳ページへ遷移
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FlashcardPage(
              vocabularyItems: itemsToUse,
              settings: _appSettings, // 設定を渡す
              onSettingsChanged: _updateSettings, // コールバックを渡す
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = "エラーが発生しました: $e";
        _loading = false;
      });
    }
  }

  /// 取得ボタンが押されたときの処理
  Future<void> _fetchSpreadsheet() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
      _csvData = null;
      _vocabularyItems = null;
    });

    String link = _linkController.text.trim();
    if (link.isEmpty) {
      setState(() {
        _errorMessage = "リンクが空です。";
        _loading = false;
      });
      return;
    }

    // シートIDの抽出
    final sheetId = _extractSheetId(link);
    if (sheetId == null) {
      setState(() {
        _errorMessage = "無効なGoogleスプレッドシートのリンクです。";
        _loading = false;
      });
      return;
    }

    // CSV取得用 URL を生成
    final csvUrl =
        "https://docs.google.com/spreadsheets/d/$sheetId/export?format=csv&gid=0";

    try {
      final response = await http.get(Uri.parse(csvUrl));
      if (response.statusCode != 200) {
        setState(() {
          _errorMessage = "データの取得に失敗しました。HTTPステータスコード: ${response.statusCode}";
          _loading = false;
        });
        return;
      }

      // シート名はシートIDを利用（必要に応じて変更可能）
      String sheetName = sheetId;

      // UTF-8でレスポンスのバイトデータをデコード
      final csvContent = utf8.decode(response.bodyBytes);

      // CSVパース（csvパッケージを利用）
      final csvTable = const CsvToListConverter().convert(csvContent);

      setState(() {
        _csvData = csvTable;
        _loading = false;
      });

      // CSVの1行目をヘッダーとして、必要なカラムの存在を確認
      if (_csvData != null && _csvData!.isNotEmpty) {
        final header = _csvData![0];
        final int wordIndex = header.indexOf("単語");
        final int meaningIndex = header.indexOf("意味");
        final int notesIndex = header.indexOf("備考");
        final int categoryIndex = header.indexOf("カテゴリー");
        final int greenIndex = header.indexOf("緑");
        final int yellowIndex = header.indexOf("黄");
        final int redIndex = header.indexOf("赤");

        if (wordIndex == -1 ||
            meaningIndex == -1 ||
            notesIndex == -1 ||
            categoryIndex == -1 ||
            greenIndex == -1 ||
            yellowIndex == -1 ||
            redIndex == -1) {
          setState(() {
            _errorMessage = "CSVに必要なカラム（単語、意味、備考、カテゴリー、緑、黄、赤）が見つかりません。";
          });
          return;
        }

        // ヘッダー以降の各行から VocabularyItem を生成
        List<VocabularyItem> allItems = [];
        for (var i = 1; i < _csvData!.length; i++) {
          var row = _csvData![i];
          if (row.length > redIndex) {
            allItems.add(
              VocabularyItem(
                word: row[wordIndex].toString(),
                meaning: row[meaningIndex].toString(),
                notes: row[notesIndex].toString(),
                category: row[categoryIndex].toString(),
                green: row[greenIndex].toString().toLowerCase() == 'true',
                yellow: row[yellowIndex].toString().toLowerCase() == 'true',
                red: row[redIndex].toString().toLowerCase() == 'true',
              ),
            );
          }
        }

        if (allItems.isEmpty) {
          setState(() {
            _errorMessage = "単語データが存在しません。";
          });
          return;
        }

        // 全データを保存
        _allVocabularyItems = allItems;

        // チェックボックスの状態に基づいてフィルタリング
        bool anyFilterActive = _filterGreen || _filterYellow || _filterRed;

        if (anyFilterActive) {
          List<VocabularyItem> filteredItems =
              allItems.where((item) {
                // いずれかの選択された色フラグがtrueの単語を含める
                return (_filterGreen && item.green) ||
                    (_filterYellow && item.yellow) ||
                    (_filterRed && item.red);
              }).toList();

          // フィルタリングして0件の場合のエラー処理
          if (filteredItems.isEmpty) {
            setState(() {
              _errorMessage = "選択された条件に一致する単語がありません。";
              _vocabularyItems = []; // 空のリストを設定
            });
            return;
          }

          setState(() {
            _vocabularyItems = filteredItems;
            // 履歴へ追加（取得時刻は現在日時）
            SheetHistory newHistory = SheetHistory(
              sheetId: sheetId, 
              displayName: sheetName, // 初期表示名はシートIDと同じ
              retrievalDate: DateTime.now(),
            );
            _history.add(newHistory);
            _saveHistory();
          });
        } else {
          setState(() {
            _vocabularyItems = allItems;
            // 履歴へ追加（取得時刻は現在日時）
            SheetHistory newHistory = SheetHistory(
              sheetId: sheetId,
              displayName: sheetName, // 初期表示名はシートIDと同じ
              retrievalDate: DateTime.now(),
            );
            _history.add(newHistory);
            _saveHistory();
          });
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = "エラーが発生しました: $e";
        _loading = false;
      });
    }
  }

  /// 単語帳開始ボタン（単語カード画面への遷移）
  Widget _buildStartButton() {
    return ElevatedButton(
      onPressed: () {
        if (_vocabularyItems != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FlashcardPage(
                vocabularyItems: _vocabularyItems!,
                settings: _appSettings, // 設定を渡す
                onSettingsChanged: _updateSettings, // コールバックを渡す
              ),
            ),
          );
        }
      },
      child: Text("単語帳を開始"),
    );
  }

  /// 履歴リストの表示ウィジェット
  Widget _buildHistoryList() {
    return _history.isEmpty
        ? SizedBox.shrink()
        : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "履歴",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            ListView.separated(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: _history.length,
              separatorBuilder: (context, index) => Divider(),
              itemBuilder: (context, index) {
                final historyItem = _history[index];
                // Dismissibleウィジェットで左スワイプでの削除機能を追加
                return Dismissible(
                  // 各履歴アイテムに一意のキーが必要
                  key: Key(historyItem.sheetId + historyItem.retrievalDate.toIso8601String()),
                  // 左スワイプのみ許可
                  direction: historyItem.isFavorite 
                      ? DismissDirection.none // お気に入りの場合はスワイプできない
                      : DismissDirection.endToStart,
                  // 確認ダイアログを表示
                  confirmDismiss: (direction) async {
                    // お気に入りの場合は削除不可
                    if (historyItem.isFavorite) {
                      return false;
                    }
                    
                    return await showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: Text("履歴の削除"),
                          content: Text("「${historyItem.displayName}」を履歴から削除しますか？"),
                          actions: <Widget>[
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: Text("キャンセル"),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              child: Text("削除", style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        );
                      },
                    );
                  },
                  // 削除時の処理
                  onDismissed: (direction) {
                    setState(() {
                      _history.removeAt(index);
                      _saveHistory(); // 履歴の変更を保存
                    });
                    // 削除完了メッセージ
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("「${historyItem.displayName}」を削除しました"),
                        duration: Duration(seconds: 2),
                        action: SnackBarAction(
                          label: '元に戻す',
                          onPressed: () {
                            setState(() {
                              _history.insert(index, historyItem);
                              _saveHistory();
                            });
                          },
                        ),
                      ),
                    );
                  },
                  // スワイプ時に表示する背景（削除アイコン付き）
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          "削除",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(
                          Icons.delete,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                  // Dismissibleの中身となるウィジェット
                  child: Container(
                    // お気に入りの場合は背景色を変更
                    color: historyItem.isFavorite ? Colors.yellow.shade50 : null,
                    child: ListTile(
                      // お気に入りボタンを追加
                      leading: IconButton(
                        icon: Icon(
                          historyItem.isFavorite ? Icons.star : Icons.star_border,
                          color: historyItem.isFavorite ? Colors.amber : Colors.grey,
                        ),
                        onPressed: () {
                          setState(() {
                            historyItem.isFavorite = !historyItem.isFavorite;
                            _saveHistory(); // お気に入り状態を保存
                          });
                        },
                      ),
                      title: Text(historyItem.displayName),
                      subtitle: Text(
                        "取得日: ${historyItem.retrievalDate.toLocal().toString().split('.').first}",
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.edit, color: Colors.blue),
                        onPressed: () {
                          // 表示名編集ダイアログを表示
                          _showEditNameDialog(historyItem);
                        },
                      ),
                      onTap: () async {
                        // 既存のコード（変更なし）
                        // 選択されたシートIDでローディング表示を開始
                        setState(() {
                          _loading = true;
                          _errorMessage = null;
                        });
                        
                        try {
                          // 保存されたシートIDからCSV取得用URLを生成
                          final csvUrl = "https://docs.google.com/spreadsheets/d/${historyItem.sheetId}/export?format=csv&gid=0";
                          
                          // 以下は_fetchSpreadsheetと同様の処理でデータを取得
                          final response = await http.get(Uri.parse(csvUrl));
                          if (response.statusCode != 200) {
                            setState(() {
                              _errorMessage = "データの取得に失敗しました。HTTPステータスコード: ${response.statusCode}";
                              _loading = false;
                            });
                            return;
                          }
                          
                          // UTF-8でレスポンスのバイトデータをデコード
                          final csvContent = utf8.decode(response.bodyBytes);
                          
                          // CSVパース
                          final csvTable = const CsvToListConverter().convert(csvContent);
                          
                          // ヘッダー処理とデータの変換（_fetchSpreadsheetと同様）
                          if (csvTable.isNotEmpty) {
                            final header = csvTable[0];
                            final int wordIndex = header.indexOf("単語");
                            final int meaningIndex = header.indexOf("意味");
                            final int notesIndex = header.indexOf("備考");
                            final int categoryIndex = header.indexOf("カテゴリー");
                            final int greenIndex = header.indexOf("緑");
                            final int yellowIndex = header.indexOf("黄");
                            final int redIndex = header.indexOf("赤");
                            
                            if (wordIndex == -1 || meaningIndex == -1 || notesIndex == -1 ||
                                categoryIndex == -1 || greenIndex == -1 || yellowIndex == -1 || redIndex == -1) {
                              setState(() {
                                _errorMessage = "CSVに必要なカラムが見つかりません。";
                                _loading = false;
                              });
                              return;
                            }
                            
                            // VocabularyItemリストを生成
                            List<VocabularyItem> items = [];
                            for (var i = 1; i < csvTable.length; i++) {
                              var row = csvTable[i];
                              if (row.length > redIndex) {
                                items.add(
                                  VocabularyItem(
                                    word: row[wordIndex].toString(),
                                    meaning: row[meaningIndex].toString(),
                                    notes: row[notesIndex].toString(),
                                    category: row[categoryIndex].toString(),
                                    green: row[greenIndex].toString().toLowerCase() == 'true',
                                    yellow: row[yellowIndex].toString().toLowerCase() == 'true',
                                    red: row[redIndex].toString().toLowerCase() == 'true',
                                  ),
                                );
                              }
                            }
                            
                            if (items.isEmpty) {
                              setState(() {
                                _errorMessage = "単語データが存在しません。";
                                _loading = false;
                              });
                              return;
                            }
                            
                            // 全データを保存
                            setState(() {
                              _allVocabularyItems = items;
                              _loading = false;
                            });
                            
                            // フィルター処理
                            bool anyFilterActive = _filterGreen || _filterYellow || _filterRed;
                            
                            if (anyFilterActive) {
                              List<VocabularyItem> filteredItems = items.where((item) {
                                return (_filterGreen && item.green) ||
                                    (_filterYellow && item.yellow) ||
                                    (_filterRed && item.red);
                              }).toList();
                              
                              if (filteredItems.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text("選択した条件に一致する単語がありません。すべての単語を表示します。"),
                                    duration: Duration(seconds: 3),
                                  ),
                                );
                                
                                // フィルター結果が空の場合は全単語を使用
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => FlashcardPage(vocabularyItems: items, settings: _appSettings, onSettingsChanged: _updateSettings,),
                                  ),
                                );
                              } else {
                                // フィルター結果があれば、それを使用
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => FlashcardPage(vocabularyItems: filteredItems, settings: _appSettings, onSettingsChanged: _updateSettings,),
                                  ),
                                );
                              }
                            } else {
                              // フィルターが選択されていない場合は全単語を使用
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => FlashcardPage(vocabularyItems: items, settings: _appSettings, onSettingsChanged: _updateSettings,),
                                ),
                              );
                            }
                          }
                        } catch (e) {
                          setState(() {
                            _errorMessage = "エラーが発生しました: $e";
                            _loading = false;
                          });
                        }
                      },
                    ),
                  ),
                );
              },
            ),
          ],
        );
  }

  @override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
        title: Text("スプレッドシート読み込み"),
        actions: [
          // 設定ボタンを追加
          IconButton(
            icon: Icon(Icons.settings),
            tooltip: '設定',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SettingsPage(
                    settings: _appSettings,
                    onSettingsChanged: _updateSettings,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    body: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // スプレッドシートの共有リンク入力フィールドとペーストボタン
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _linkController,
                    decoration: InputDecoration(
                      labelText: "スプレッドシートの共有リンク",
                      border: OutlineInputBorder(),
                      // クリアボタンを追加
                      suffixIcon: _linkController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear),
                              onPressed: () {
                                _linkController.clear();
                              },
                            )
                          : null,
                    ),
                  ),
                ),
                SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.content_paste),
                  tooltip: "クリップボードから貼り付け",
                  onPressed: _pasteFromClipboard,
                ),
              ],
            ),
            SizedBox(height: 16),
            
            // エラーメッセージがあれば表示（位置を移動：入力フォームの直下）
            if (_errorMessage != null)
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),

            SizedBox(height: _errorMessage != null ? 16 : 0),
            
            // リンクが入力されている場合は単語帳開始ボタンを表示、
            // 入力されていない場合はヘルプメッセージを表示
            if (_linkController.text.trim().isNotEmpty)
              ElevatedButton(
                onPressed: _loading ? null : _fetchAndStartFlashcards,
                child: _loading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text("単語帳を開始"),
              )
            else
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "スプレッドシートの共有リンク（リンクを知っている全員）を入力してください。",
                  style: TextStyle(color: Colors.blue.shade800),
                  textAlign: TextAlign.center,
                ),
              ),
            
            SizedBox(height: 16),
            
            // 色フィルターチェックボックス
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // 緑チェックボックス
                        Row(
                          children: [
                            Checkbox(
                              value: _filterGreen,
                              onChanged: (value) {
                                setState(() {
                                  _filterGreen = value!;
                                });
                                _applyFilters(); // フィルター適用
                              },
                              activeColor: Colors.green,
                            ),
                            Text('緑'),
                          ],
                        ),
                        SizedBox(width: 16),
                        // 黄色チェックボックス
                        Row(
                          children: [
                            Checkbox(
                              value: _filterYellow,
                              onChanged: (value) {
                                setState(() {
                                  _filterYellow = value!;
                                });
                                _applyFilters(); // フィルター適用
                              },
                              fillColor: MaterialStateProperty.resolveWith(
                                (states) =>
                                    states.contains(MaterialState.selected)
                                        ? Colors.yellow
                                        : null,
                              ),
                            ),
                            Text('黄色'),
                          ],
                        ),
                        SizedBox(width: 16),
                        // 赤チェックボックス
                        Row(
                          children: [
                            Checkbox(
                              value: _filterRed,
                              onChanged: (value) {
                                setState(() {
                                  _filterRed = value!;
                                });
                                _applyFilters(); // フィルター適用
                              },
                              activeColor: Colors.red,
                            ),
                            Text('赤'),
                          ],
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      'チェックボックスにマークがある場合、その単語のみ出題\n（マークがない場合はすべて出題）',
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 20),
            
            // 履歴リストの表示
            _buildHistoryList(),
          ],
        ),
      ),
    ),
  );
}

  /// 履歴アイテムの表示名を編集するダイアログ
  void _showEditNameDialog(SheetHistory historyItem) {
    final TextEditingController _nameController = TextEditingController();
    _nameController.text = historyItem.displayName;
    
    // テキスト入力状態を保持する変数
    bool hasText = true;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          // _nameControllerにリスナーを追加
          _nameController.addListener(() {
            final newHasText = _nameController.text.isNotEmpty;
            if (hasText != newHasText) {
              setState(() {
                hasText = newHasText;
              });
            }
          });
          
          return AlertDialog(
            title: Text("表示名の編集"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("シートID: ${historyItem.sheetId}", style: TextStyle(fontSize: 12, color: Colors.grey)),
                SizedBox(height: 8),
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: "表示名",
                    border: OutlineInputBorder(),
                    hintText: "最大100文字まで",
                    // クリアボタンを追加
                    suffixIcon: hasText
                        ? IconButton(
                            icon: Icon(Icons.clear),
                            onPressed: () {
                              _nameController.clear();
                            },
                          )
                        : null,
                  ),
                  maxLength: 100, // 100文字制限
                  autofocus: true,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("キャンセル"),
              ),
              ElevatedButton(
                onPressed: () {
                  // 入力された表示名を設定（空の場合はシートIDを使用）
                  String newDisplayName = _nameController.text.trim();
                  if (newDisplayName.isEmpty) {
                    newDisplayName = historyItem.sheetId;
                  }
                  
                  setState(() {
                    historyItem.displayName = newDisplayName;
                    this.setState(() {
                      _saveHistory(); // 変更を保存
                    });
                  });
                  
                  Navigator.pop(context);
                },
                child: Text("保存"),
              ),
            ],
          );
        }
      ),
    );
  }
}

/// 単語カード画面（フラッシュカード形式で表示）
class FlashcardPage extends StatefulWidget {
  final List<VocabularyItem> vocabularyItems;
  final AppSettings settings; // 設定を追加
  final Function(AppSettings) onSettingsChanged; // コールバックを追加

  FlashcardPage({
    required this.vocabularyItems, 
    required this.settings,
    required this.onSettingsChanged, // 設定変更コールバック
  });

  @override
  _FlashcardPageState createState() => _FlashcardPageState();
}

class _FlashcardPageState extends State<FlashcardPage> {
  int _currentIndex = 0;
  bool _isFront = true; // 表：true, 裏：false
  // 設定を内部状態として保持するように修正
  late AppSettings _currentSettings;

  @override
  void initState() {
    super.initState();
    // 初期表示時に単語リストをシャッフル
    widget.vocabularyItems.shuffle();
    // 初期設定を内部状態にコピー
    _currentSettings = widget.settings;
  }

  /// カードの裏表を反転
  void _flipCard() {
    setState(() {
      _isFront = !_isFront;
    });
  }

  /// 次のカードへ
  void _nextCard() {
    if (_currentIndex < widget.vocabularyItems.length - 1) {
      setState(() {
        _currentIndex++;
        _isFront = true;
      });
    }
  }

  /// 前のカードへ
  void _previousCard() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _isFront = true;
      });
    }
  }

  /// シャッフル機能：リストをランダムに並び替え、最初のカードに戻る
  void _shuffleCards() {
    setState(() {
      widget.vocabularyItems.shuffle();
      _currentIndex = 0;
      _isFront = true;
    });
  }

  /// 最初から：1番目のカードに戻る
  void _restartCards() {
    setState(() {
      _currentIndex = 0;
      _isFront = true;
    });
  }

  /// カード右上に表示する小さな丸インジケーター
  Widget _buildIndicator(bool flag, Color color) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade500, width: 0.5),
        borderRadius: BorderRadius.circular(2),
        color: flag ? color : Colors.grey.shade400,
      ),
      child:
          flag
              ? Icon(Icons.check, size: 12, color: Colors.grey.shade100)
              : Icon(Icons.check, size: 12, color: Colors.black87),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentItem = widget.vocabularyItems[_currentIndex];
    
    // 内部状態から文字サイズを取得するよう変更
    final textSize = _currentSettings.textSize;    
    final notesFontSize = _currentSettings.notesSize;

    return Scaffold(
      appBar: AppBar(
        title: Text("単語帳"),
        actions: [
          // 設定ボタンを追加
          IconButton(
            icon: Icon(Icons.settings),
            tooltip: '設定',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SettingsPage(
                    // 現在の内部状態の設定を渡す
                    settings: _currentSettings,
                    onSettingsChanged: (newSettings) {
                      // 1. 親コンポーネントに通知
                      widget.onSettingsChanged(newSettings);
                      
                      // 2. 自身の状態も更新（これが欠けていた）
                      setState(() {
                        _currentSettings = newSettings;
                      });
                    },
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 上部ボタン部分
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(onPressed: _shuffleCards, child: Text("シャッフル")),
                SizedBox(width: 8),
                ElevatedButton(onPressed: _restartCards, child: Text("最初から")),
              ],
            ),
            SizedBox(height: 12),
            // カード部分（編集不要）
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Card(
                  elevation: 4,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Stack(
                        children: [
                          // 左上：カテゴリー表示（変更なし）
                          Positioned(
                            top: 8,
                            left: 8,
                            child: Text(
                              currentItem.category,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                          ),
                          // メインコンテンツ - 新しいサイズ設定を使用
                          Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Center(
                              child: _isFront
                                  ? // 表面（単語）
                                    SingleChildScrollView(
                                      physics: AlwaysScrollableScrollPhysics(),
                                      child: Container(
                                        width: double.infinity,
                                        child: Text(
                                          currentItem.word,
                                          style: TextStyle(fontSize: textSize), // 共通サイズを使用
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    )
                                  : // 裏面（意味と備考）
                                    SingleChildScrollView(
                                      physics: AlwaysScrollableScrollPhysics(),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Container(
                                            width: double.infinity,
                                            child: Text(
                                              currentItem.meaning,
                                              style: TextStyle(fontSize: textSize), // 共通サイズを使用
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                          SizedBox(height: 10),
                                          Container(
                                            width: double.infinity,
                                            child: Text(
                                              currentItem.notes,
                                              style: TextStyle(fontSize: notesFontSize),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                            ),
                          ),
                          // 右上：色フラグインジケーター（変更なし）
                          // ...
                          // 右下：カード番号表示（変更なし）
                          // ...
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
            SizedBox(height: 12),
          ],
        ),
      ),
      // bottomNavigationBar 部分は変更なし
      bottomNavigationBar: LayoutBuilder(
        builder: (context, constraints) {
          double totalWidth = constraints.maxWidth;
          double effectiveWidth = totalWidth - 16;
          double sideButtonWidth = effectiveWidth * 5 / 20;
          double rowHeight = sideButtonWidth; // 戻る、次へは正方形

          return Padding(
            padding: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 32.0),
            child: SizedBox(
              height: rowHeight,
              child: Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: SizedBox(
                      height: rowHeight,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromARGB(
                            255,
                            255,
                            221,
                            221,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          textStyle: TextStyle(fontSize: 20),
                        ),
                        onPressed: _currentIndex == 0 ? null : _previousCard,
                        child: Text("戻る"),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    flex: 10,
                    child: SizedBox(
                      height: rowHeight,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromRGBO(
                            220,
                            233,
                            255,
                            1,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          textStyle: TextStyle(fontSize: 20),
                        ),
                        onPressed: _flipCard,
                        child: Text("めくる"),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    flex: 5,
                    child: SizedBox(
                      height: rowHeight,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromARGB(
                            255,
                            221,
                            255,
                            222,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          textStyle: TextStyle(fontSize: 20),
                        ),
                        onPressed:
                            _currentIndex == widget.vocabularyItems.length - 1
                                ? null
                                : _nextCard,
                        child: Text("次へ"),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
