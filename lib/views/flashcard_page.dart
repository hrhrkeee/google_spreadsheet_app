import 'package:flutter/material.dart';
import '../models/vocabulary_item.dart';
import '../models/app_settings.dart';
import 'settings_page.dart';

/// 単語カード画面
class FlashcardPage extends StatefulWidget {
  final List<VocabularyItem> vocabularyItems;
  final AppSettings settings;
  final Function(AppSettings) onSettingsChanged;

  const FlashcardPage({
    required this.vocabularyItems, 
    required this.settings,
    required this.onSettingsChanged,
  });

  @override
  _FlashcardPageState createState() => _FlashcardPageState();
}

class _FlashcardPageState extends State<FlashcardPage> {
  int _currentIndex = 0;
  bool _isFront = true;
  late AppSettings _currentSettings;

  @override
  void initState() {
    super.initState();
    widget.vocabularyItems.shuffle();
    _currentSettings = widget.settings;
  }

  void _flipCard() {
    setState(() {
      _isFront = !_isFront;
    });
  }

  void _nextCard() {
    if (_currentIndex < widget.vocabularyItems.length - 1) {
      setState(() {
        _currentIndex++;
        _isFront = true;
      });
    }
  }

  void _previousCard() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _isFront = true;
      });
    }
  }

  void _shuffleCards() {
    setState(() {
      widget.vocabularyItems.shuffle();
      _currentIndex = 0;
      _isFront = true;
    });
  }

  void _restartCards() {
    setState(() {
      _currentIndex = 0;
      _isFront = true;
    });
  }

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
    final textSize = _currentSettings.textSize;    
    final notesFontSize = _currentSettings.notesSize;
    final edgeColor = AppSettings.getColorFromString(_currentSettings.edgeColor);

    return Scaffold(
      appBar: AppBar(
        title: Text("単語帳"),
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            tooltip: '設定',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SettingsPage(
                    settings: _currentSettings,
                    onSettingsChanged: (newSettings) {
                      widget.onSettingsChanged(newSettings);
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
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(onPressed: _shuffleCards, child: Text("シャッフル")),
                SizedBox(width: 8),
                ElevatedButton(onPressed: _restartCards, child: Text("最初から")),
              ],
            ),
            SizedBox(height: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: _buildCard(currentItem, textSize, notesFontSize, edgeColor),
              ),
            ),
            SizedBox(height: 12),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildCard(VocabularyItem item, double textSize, double notesFontSize, Color edgeColor) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              if (!_isFront) ...[
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 4,
                    color: edgeColor,
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 4,
                    color: edgeColor,
                  ),
                ),
              ],
              
              Positioned(
                top: 8,
                left: 8,
                child: Text(
                  item.category,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                ),
              ),
              
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Center(
                  child: _isFront
                      ? _buildFrontContent(item, textSize)
                      : _buildBackContent(item, textSize, notesFontSize),
                ),
              ),
              
              Positioned(
                top: 8,
                right: 8,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildIndicator(item.green, Colors.green),
                    SizedBox(width: 4),
                    _buildIndicator(item.yellow, Colors.yellow),
                    SizedBox(width: 4),
                    _buildIndicator(item.red, Colors.red),
                  ],
                ),
              ),
              
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
          );
        },
      ),
    );
  }

  Widget _buildFrontContent(VocabularyItem item, double textSize) {
    return SingleChildScrollView(
      physics: AlwaysScrollableScrollPhysics(),
      child: Container(
        width: double.infinity,
        child: Text(
          item.word,
          style: TextStyle(fontSize: textSize),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildBackContent(VocabularyItem item, double textSize, double notesFontSize) {
    return SingleChildScrollView(
      physics: AlwaysScrollableScrollPhysics(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: double.infinity,
            child: Text(
              item.meaning,
              style: TextStyle(fontSize: textSize),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: 10),
          Container(
            width: double.infinity,
            child: Text(
              item.notes,
              style: TextStyle(fontSize: notesFontSize),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        double totalWidth = constraints.maxWidth;
        double effectiveWidth = totalWidth - 16;
        double sideButtonWidth = effectiveWidth * 5 / 20;
        double rowHeight = sideButtonWidth;

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
                        backgroundColor: const Color.fromARGB(255, 255, 221, 221),
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
                        backgroundColor: const Color.fromRGBO(220, 233, 255, 1),
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
                        backgroundColor: const Color.fromARGB(255, 221, 255, 222),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        textStyle: TextStyle(fontSize: 20),
                      ),
                      onPressed: _currentIndex == widget.vocabularyItems.length - 1
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
    );
  }
}
