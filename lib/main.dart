import 'dart:convert';
import 'dart:html' as html; // localStorage 利用のため
import 'package:flutter/material.dart';
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

/// 単語データを保持するモデルクラス（カテゴリーと色フラグ付き）
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
  final String sheetName;
  final DateTime retrievalDate;
  final List<VocabularyItem> vocabularyItems;

  SheetHistory({
    required this.sheetName,
    required this.retrievalDate,
    required this.vocabularyItems,
  });

  Map<String, dynamic> toMap() {
    return {
      'sheetName': sheetName,
      'retrievalDate': retrievalDate.toIso8601String(),
      'vocabularyItems': vocabularyItems.map((item) => item.toMap()).toList(),
    };
  }

  factory SheetHistory.fromMap(Map<String, dynamic> map) {
    return SheetHistory(
      sheetName: map['sheetName'],
      retrievalDate: DateTime.parse(map['retrievalDate']),
      vocabularyItems: List<VocabularyItem>.from(
        (map['vocabularyItems'] as List).map(
          (item) => VocabularyItem.fromMap(item),
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

  // 色フィルター用チェックボックス状態
  bool _filterGreen = false;
  bool _filterYellow = false;
  bool _filterRed = false;

  // 履歴リスト（localStorage を利用して永続化）
  final List<SheetHistory> _history = [];
  final String _storageKey = "sheet_history";

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
        _errorMessage = "選択された条件に一致する単語がありません。";
        // 空リストの場合でも元データは保持
        _vocabularyItems = [];
      } else {
        _errorMessage = null;
        _vocabularyItems = filtered;
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

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
              sheetName: sheetName,
              retrievalDate: DateTime.now(),
              vocabularyItems: filteredItems,
            );
            _history.add(newHistory);
            _saveHistory();
          });
        } else {
          setState(() {
            _vocabularyItems = allItems;
            // 履歴へ追加（取得時刻は現在日時）
            SheetHistory newHistory = SheetHistory(
              sheetName: sheetName,
              retrievalDate: DateTime.now(),
              vocabularyItems: allItems,
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
              builder:
                  (context) =>
                      FlashcardPage(vocabularyItems: _vocabularyItems!),
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
                return ListTile(
                  title: Text(historyItem.sheetName),
                  subtitle: Text(
                    "取得日: ${historyItem.retrievalDate.toLocal().toString().split('.').first}",
                  ),
                  onTap: () {
                    // 履歴アイテムの全単語を全単語リストにセット
                    _allVocabularyItems = historyItem.vocabularyItems;

                    // 現在のフィルター状態を適用
                    bool anyFilterActive =
                        _filterGreen || _filterYellow || _filterRed;

                    if (anyFilterActive) {
                      // フィルターが選択されている場合は、それを適用
                      List<VocabularyItem> filteredItems =
                          historyItem.vocabularyItems.where((item) {
                            return (_filterGreen && item.green) ||
                                (_filterYellow && item.yellow) ||
                                (_filterRed && item.red);
                          }).toList();

                      // フィルターの結果が空の場合はアラートを表示
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
                            builder:
                                (context) => FlashcardPage(
                                  vocabularyItems: historyItem.vocabularyItems,
                                ),
                          ),
                        );
                      } else {
                        // フィルター結果があれば、それを使用
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => FlashcardPage(
                                  vocabularyItems: filteredItems,
                                ),
                          ),
                        );
                      }
                    } else {
                      // フィルターが選択されていない場合は全単語を使用
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => FlashcardPage(
                                vocabularyItems: historyItem.vocabularyItems,
                              ),
                        ),
                      );
                    }
                  },
                );
              },
            ),
          ],
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("スプレッドシート読み込み")),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // スプレッドシートの共有リンク入力フィールド
              TextField(
                controller: _linkController,
                decoration: InputDecoration(
                  labelText: "スプレッドシートの共有リンク",
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 10),
              // 取得ボタン
              ElevatedButton(
                onPressed: _loading ? null : _fetchSpreadsheet,
                child:
                    _loading
                        ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : Text("取得"),
              ),
              SizedBox(height: 20),

              // 追加：色フィルターチェックボックス
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

              if (_errorMessage != null)
                Text(_errorMessage!, style: TextStyle(color: Colors.red)),
              // CSV取得後、単語帳開始ボタンを表示（必要なカラムが存在する場合）
              if (_vocabularyItems != null) _buildStartButton(),
              SizedBox(height: 20),
              // 履歴リストの表示
              _buildHistoryList(),
            ],
          ),
        ),
      ),
    );
  }
}

/// 単語カード画面（フラッシュカード形式で表示）
class FlashcardPage extends StatefulWidget {
  final List<VocabularyItem> vocabularyItems;

  FlashcardPage({required this.vocabularyItems});

  @override
  _FlashcardPageState createState() => _FlashcardPageState();
}

class _FlashcardPageState extends State<FlashcardPage> {
  int _currentIndex = 0;
  bool _isFront = true; // 表：true, 裏：false

  @override
  void initState() {
    super.initState();
    // 初期表示時に単語リストをシャッフル
    widget.vocabularyItems.shuffle();
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
    return Scaffold(
      appBar: AppBar(title: Text("単語帳")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 上部の「シャッフル」「最初から」ボタン
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(onPressed: _shuffleCards, child: Text("シャッフル")),
                SizedBox(width: 8),
                ElevatedButton(onPressed: _restartCards, child: Text("最初から")),
              ],
            ),
            SizedBox(height: 16),
            // カード部分
            Expanded(
              child: Center(
                child: Card(
                  elevation: 4,
                  child: AspectRatio(
                    aspectRatio: 1.6,
                    child: Stack(
                      children: [
                        // 左上：カテゴリー表示
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
                        Center(
                          child:
                              _isFront
                                  ? Text(
                                    currentItem.word,
                                    style: TextStyle(fontSize: 24),
                                    textAlign: TextAlign.center,
                                  )
                                  : Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        currentItem.meaning,
                                        style: TextStyle(fontSize: 20),
                                        textAlign: TextAlign.center,
                                      ),
                                      SizedBox(height: 10),
                                      Text(
                                        currentItem.notes,
                                        style: TextStyle(fontSize: 16),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                        ),
                        // 右上：色フラグインジケーター
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildIndicator(currentItem.green, Colors.green),
                              SizedBox(width: 4),
                              _buildIndicator(
                                currentItem.yellow,
                                Colors.yellow,
                              ),
                              SizedBox(width: 4),
                              _buildIndicator(currentItem.red, Colors.red),
                            ],
                          ),
                        ),
                        // 追加：右下にカード番号表示
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: Text(
                            "${_currentIndex + 1}/${widget.vocabularyItems.length}",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      // 下部ナビゲーションボタン
      // FlashcardPage 内の build メソッドの bottomNavigationBar 部分（修正例）
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
