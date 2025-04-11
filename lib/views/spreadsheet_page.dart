import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/vocabulary_item.dart';
import '../models/sheet_history.dart';
import '../models/app_settings.dart';
import '../services/spreadsheet_service.dart';
import '../services/storage_service.dart';
import 'flashcard_page.dart';
import 'settings_page.dart';

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
  bool _linkHasText = false;

  // 色フィルター用チェックボックス状態
  bool _filterGreen = false;
  bool _filterYellow = false;
  bool _filterRed = false;

  // 履歴リスト
  final List<SheetHistory> _history = [];

  // アプリ設定
  late AppSettings _appSettings;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _loadSettings();
    
    _linkController.addListener(() {
      final hasText = _linkController.text.isNotEmpty;
      if (hasText != _linkHasText) {
        setState(() {
          _linkHasText = hasText;
          if (!hasText) {
            _errorMessage = null;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _linkController.dispose();
    super.dispose();
  }

  // 設定関連メソッド
  void _loadSettings() {
    setState(() {
      _appSettings = StorageService.loadSettings();
    });
  }
  
  void _updateSettings(AppSettings newSettings) {
    setState(() {
      _appSettings = newSettings;
      StorageService.saveSettings(newSettings);
    });
  }
  
  // 履歴関連メソッド
  void _loadHistory() {
    setState(() {
      _history.clear();
      _history.addAll(StorageService.loadHistory());
    });
  }
  
  void _saveHistory() {
    StorageService.saveHistory(_history);
  }

  // フィルター関連メソッド
  void _applyFilters() {
    if (_allVocabularyItems == null || _allVocabularyItems!.isEmpty) {
      return;
    }

    setState(() {
      bool anyFilterActive = _filterGreen || _filterYellow || _filterRed;

      if (!anyFilterActive) {
        _vocabularyItems = _allVocabularyItems;
        _errorMessage = null;
        return;
      }

      List<VocabularyItem> filtered = _allVocabularyItems!.where((item) {
        return item.matchesColorFilter(
          filterGreen: _filterGreen,
          filterYellow: _filterYellow,
          filterRed: _filterRed
        );
      }).toList();

      if (filtered.isEmpty) {
        _vocabularyItems = _allVocabularyItems;
        
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

  // クリップボード関連メソッド
  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data != null && data.text != null) {
      setState(() {
        _linkController.text = data.text!;
      });
    }
  }

  // スプレッドシート取得関連メソッド
  Future<List<VocabularyItem>> _processSpreadsheetData(String sheetId) async {
    try {
      final csvData = await SpreadsheetService.fetchCsvData(sheetId);
      setState(() {
        _csvData = csvData;
      });
      
      return SpreadsheetService.createVocabularyItems(csvData);
    } catch (e) {
      throw e;
    }
  }

  List<VocabularyItem> _applyColorFilters(List<VocabularyItem> items) {
    bool anyFilterActive = _filterGreen || _filterYellow || _filterRed;
    
    if (!anyFilterActive) {
      return items;
    }
    
    List<VocabularyItem> filtered = items.where((item) {
      return item.matchesColorFilter(
        filterGreen: _filterGreen,
        filterYellow: _filterYellow,
        filterRed: _filterRed
      );
    }).toList();
    
    if (filtered.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("選択した条件に一致する単語がありません。すべての単語を表示します。"),
          duration: Duration(seconds: 3),
        ),
      );
      return items;
    }
    
    return filtered;
  }

  // 履歴アイテム用メソッド
  Future<void> _loadHistoryItem(SheetHistory historyItem) async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    
    // ローディングオーバーレイを表示
    final overlayEntry = _showLoadingOverlay();
    
    try {
      final items = await _processSpreadsheetData(historyItem.sheetId);
      
      setState(() {
        _allVocabularyItems = items;
        _loading = false;
      });
      
      final filteredItems = _applyColorFilters(items);
      
      // オーバーレイを削除
      overlayEntry.remove();
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FlashcardPage(
            vocabularyItems: filteredItems,
            settings: _appSettings,
            onSettingsChanged: _updateSettings,
          ),
        ),
      );
    } catch (e) {
      // オーバーレイを削除
      overlayEntry.remove();
      
      setState(() {
        _errorMessage = "エラーが発生しました: $e";
        _loading = false;
      });
    }
  }

  /// 取得ボタンが押されたときの処理
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

    final sheetId = SpreadsheetService.extractSheetId(link);
    if (sheetId == null) {
      setState(() {
        _errorMessage = "無効なGoogleスプレッドシートのリンクです。";
        _loading = false;
      });
      return;
    }

    // ローディングオーバーレイを表示
    final overlayEntry = _showLoadingOverlay();

    try {
      final items = await _processSpreadsheetData(sheetId);
      
      // 履歴へ追加
      SheetHistory newHistory = SheetHistory(
        sheetId: sheetId,
        displayName: sheetId,
        retrievalDate: DateTime.now(),
      );
      
      setState(() {
        _allVocabularyItems = items;
        _history.add(newHistory);
        _loading = false;
      });
      
      _saveHistory();
      
      final filteredItems = _applyColorFilters(items);
      
      // オーバーレイを削除
      overlayEntry.remove();
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FlashcardPage(
            vocabularyItems: filteredItems,
            settings: _appSettings,
            onSettingsChanged: _updateSettings,
          ),
        ),
      );
    } catch (e) {
      // オーバーレイを削除
      overlayEntry.remove();
      
      setState(() {
        _errorMessage = "エラーが発生しました: $e";
        _loading = false;
      });
    }
  }

  // 読み込み中オーバーレイを表示するメソッド
  OverlayEntry _showLoadingOverlay() {
    OverlayEntry overlayEntry = OverlayEntry(
      builder: (context) => Container(
        color: Colors.black54,
        child: Center(
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    "単語帳を読み込み中...",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(overlayEntry);
    return overlayEntry;
  }

  // UIパーツ構築メソッド
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
                itemBuilder: (context, index) => _buildHistoryItem(index),
              ),
            ],
          );
  }

  Widget _buildHistoryItem(int index) {
    final historyItem = _history[index];
    
    return Dismissible(
      key: Key(historyItem.sheetId + historyItem.retrievalDate.toIso8601String()),
      direction: historyItem.isFavorite ? DismissDirection.none : DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        if (historyItem.isFavorite) return false;
        
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
      onDismissed: (direction) {
        setState(() {
          _history.removeAt(index);
          _saveHistory();
        });
        
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
      child: Container(
        color: historyItem.isFavorite ? Colors.yellow.shade50 : null,
        child: ListTile(
          leading: IconButton(
            icon: Icon(
              historyItem.isFavorite ? Icons.star : Icons.star_border,
              color: historyItem.isFavorite ? Colors.amber : Colors.grey,
            ),
            onPressed: () {
              setState(() {
                historyItem.isFavorite = !historyItem.isFavorite;
                _saveHistory();
              });
            },
          ),
          title: Text(historyItem.displayName),
          subtitle: Text(
            "取得日: ${historyItem.retrievalDate.toLocal().toString().split('.').first}",
          ),
          trailing: IconButton(
            icon: Icon(Icons.edit, color: Colors.blue),
            onPressed: () => _showEditNameDialog(historyItem),
          ),
          onTap: () => _loadHistoryItem(historyItem),
        ),
      ),
    );
  }

  void _showEditNameDialog(SheetHistory historyItem) {
    final TextEditingController _nameController = TextEditingController();
    _nameController.text = historyItem.displayName;
    bool hasText = true;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
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
                    suffixIcon: hasText
                        ? IconButton(
                            icon: Icon(Icons.clear),
                            onPressed: () {
                              _nameController.clear();
                            },
                          )
                        : null,
                  ),
                  maxLength: 100,
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
                  String newDisplayName = _nameController.text.trim();
                  if (newDisplayName.isEmpty) {
                    newDisplayName = historyItem.sheetId;
                  }
                  
                  setState(() {
                    historyItem.displayName = newDisplayName;
                    this.setState(() {
                      _saveHistory();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("スプレッドシート読み込み"),
        actions: [
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
              _buildLinkInputSection(),
              SizedBox(height: 16),
              
              if (_errorMessage != null)
                _buildErrorMessage(),

              SizedBox(height: _errorMessage != null ? 16 : 0),
              
              _buildActionButton(),
              
              SizedBox(height: 16),
              
              _buildColorFilterCard(),
              
              SizedBox(height: 20),
              
              _buildHistoryList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLinkInputSection() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _linkController,
            decoration: InputDecoration(
              labelText: "スプレッドシートの共有リンク",
              border: OutlineInputBorder(),
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
    );
  }

  Widget _buildErrorMessage() {
    return Container(
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
    );
  }

  Widget _buildActionButton() {
    if (_linkController.text.trim().isNotEmpty) {
      return ElevatedButton(
        onPressed: _loading ? null : _fetchAndStartFlashcards,
        child: Text("単語帳を開始"),
      );
    } else {
      return Container(
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
      );
    }
  }

  Widget _buildColorFilterCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Checkbox(
                      value: _filterGreen,
                      onChanged: (value) {
                        setState(() {
                          _filterGreen = value!;
                        });
                        _applyFilters();
                      },
                      activeColor: Colors.green,
                    ),
                    Text('緑'),
                  ],
                ),
                SizedBox(width: 16),
                Row(
                  children: [
                    Checkbox(
                      value: _filterYellow,
                      onChanged: (value) {
                        setState(() {
                          _filterYellow = value!;
                        });
                        _applyFilters();
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
                Row(
                  children: [
                    Checkbox(
                      value: _filterRed,
                      onChanged: (value) {
                        setState(() {
                          _filterRed = value!;
                        });
                        _applyFilters();
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
    );
  }
}
