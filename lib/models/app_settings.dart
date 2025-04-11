import 'package:flutter/material.dart';

/// アプリの設定を管理するクラス
class AppSettings {
  // デフォルト値
  static const double DEFAULT_TEXT_SIZE = 24.0;
  static const double DEFAULT_NOTES_SIZE = 16.0;
  static const String DEFAULT_EDGE_COLOR = "blue";
  
  // 単語カード内の文字サイズ
  final double textSize;
  final double notesSize;
  
  // カード裏面のエッジカラー
  final String edgeColor;

  const AppSettings({
    this.textSize = DEFAULT_TEXT_SIZE,
    this.notesSize = DEFAULT_NOTES_SIZE,
    this.edgeColor = DEFAULT_EDGE_COLOR,
  });

  // JSONに変換するメソッド
  Map<String, dynamic> toMap() {
    return {
      'textSize': textSize,
      'notesSize': notesSize,
      'edgeColor': edgeColor,
    };
  }

  // JSONから復元するファクトリメソッド
  factory AppSettings.fromMap(Map<String, dynamic> map) {
    // 後方互換性のための処理
    if (map.containsKey('wordSize') && map.containsKey('meaningSize')) {
      final textSize = map['wordSize'] ?? DEFAULT_TEXT_SIZE;
      return AppSettings(
        textSize: textSize,
        notesSize: map['notesSize'] ?? DEFAULT_NOTES_SIZE,
        edgeColor: map['edgeColor'] ?? DEFAULT_EDGE_COLOR,
      );
    }
    
    // 新しい形式の場合
    return AppSettings(
      textSize: map['textSize'] ?? DEFAULT_TEXT_SIZE,
      notesSize: map['notesSize'] ?? DEFAULT_NOTES_SIZE,
      edgeColor: map['edgeColor'] ?? DEFAULT_EDGE_COLOR,
    );
  }
  
  // 色名から Color オブジェクトを取得するヘルパーメソッド
  static Color getColorFromString(String colorName) {
    switch (colorName) {
      case "red": return Colors.red;
      case "yellow": return Colors.yellow;
      case "green": return Colors.green;
      case "blue": return Colors.blue;
      case "purple": return Colors.purple;
      default: return Colors.blue;
    }
  }
  
  // 設定を更新した新しいインスタンスを作成
  AppSettings copyWith({
    double? textSize,
    double? notesSize,
    String? edgeColor,
  }) {
    return AppSettings(
      textSize: textSize ?? this.textSize,
      notesSize: notesSize ?? this.notesSize,
      edgeColor: edgeColor ?? this.edgeColor,
    );
  }
}
