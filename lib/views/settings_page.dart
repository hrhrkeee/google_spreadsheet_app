import 'package:flutter/material.dart';
import '../models/app_settings.dart';

/// 設定画面
class SettingsPage extends StatefulWidget {
  final AppSettings settings;
  final Function(AppSettings) onSettingsChanged;

  const SettingsPage({required this.settings, required this.onSettingsChanged});

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late double _textSize;
  late double _notesSize;
  late String _edgeColor;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _textSize = widget.settings.textSize;
    _notesSize = widget.settings.notesSize;
    _edgeColor = widget.settings.edgeColor;
  }

  void _saveSettings() {
    final newSettings = AppSettings(
      textSize: _textSize,
      notesSize: _notesSize,
      edgeColor: _edgeColor,
    );
    widget.onSettingsChanged(newSettings);
    Navigator.pop(context);
  }
  
  Future<bool?> _showConfirmationDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('設定の保存'),
        content: Text('変更した設定を保存しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('いいえ'),
          ),
          ElevatedButton(
            onPressed: () {
              _saveSettings();
              Navigator.of(context).pop(true);
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
        if (_hasChanges) {
          final result = await _showConfirmationDialog();
          return result == null || result == false;
        }
        return true;
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
                _buildTextSizeCard(),
                SizedBox(height: 16),
                _buildEdgeColorCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextSizeCard() {
    return Card(
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
                              _notesSize != widget.settings.notesSize ||
                              _edgeColor != widget.settings.edgeColor;
                });
              },
            ),
            
            SizedBox(height: 16),
            
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
                              _notesSize != widget.settings.notesSize ||
                              _edgeColor != widget.settings.edgeColor;
                });
              },
            ),
            
            SizedBox(height: 16),
            
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
    );
  }

  Widget _buildEdgeColorCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'カード裏面',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            
            Text('エッジのカラー:'),
            SizedBox(height: 12),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildColorOption("red", "赤"),
                _buildColorOption("yellow", "黄"),
                _buildColorOption("green", "緑"),
                _buildColorOption("blue", "青"),
                _buildColorOption("purple", "紫"),
              ],
            ),
            
            SizedBox(height: 24),
            
            Text('プレビュー:'),
            SizedBox(height: 8),
            Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 4,
                      color: AppSettings.getColorFromString(_edgeColor),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 4,
                      color: AppSettings.getColorFromString(_edgeColor),
                    ),
                  ),
                  
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("意味のサンプル", style: TextStyle(fontSize: _textSize)),
                        SizedBox(height: 8),
                        Text("備考のサンプル", style: TextStyle(fontSize: _notesSize)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildColorOption(String colorName, String displayName) {
    bool isSelected = _edgeColor == colorName;
    Color color = AppSettings.getColorFromString(colorName);
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _edgeColor = colorName;
          _hasChanges = _textSize != widget.settings.textSize || 
                      _notesSize != widget.settings.notesSize ||
                      _edgeColor != widget.settings.edgeColor;
        });
      },
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              border: Border.all(
                color: isSelected ? Colors.black : Colors.grey,
                width: isSelected ? 3 : 1,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          SizedBox(height: 4),
          Text(
            displayName,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
