import 'dart:convert';
import 'package:flutter/material.dart' hide Ink;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:google_mlkit_digital_ink_recognition/google_mlkit_digital_ink_recognition.dart'; // ML Kit Digital Ink
import 'package:sqflite/sqflite.dart';
import '../models/case_model.dart';
import '../utils/file_helper.dart';
import '../utils/db_helper.dart';
import 'dart:ui' as ui;

// InkCanvas for drawing and recognizing text
class InkCanvas extends StatefulWidget {
  final CaseObject? caseObject;
  final String caseId;
  final Function(CaseObject) onSave;
  final FileHelper fileHelper;
  final DatabaseHelper dbHelper;

  const InkCanvas(
      {super.key,
      required this.caseObject,
      required this.caseId,
      required this.onSave,
      required this.fileHelper,
      required this.dbHelper});

  @override
  _InkCanvasState createState() => _InkCanvasState();
}

class _InkCanvasState extends State<InkCanvas> {
  late DigitalInkRecognizer? recognizer;
  final DigitalInkRecognizerModelManager _modelManager =
      DigitalInkRecognizerModelManager();
  String recognizedText = '';
  final DrawInk _ink = DrawInk();
  List<DrawStrokePoint> _points = [];

  @override
  void dispose() {
    try {
      if (recognizer != null) {
        recognizer!.close();
      }
    } finally {
      recognizer = null;
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _downloadModelIfNeeded(); // Automatically download the model on initialization
    if (widget.caseObject!.path.isNotEmpty) {
      _loadInkFromFile(widget.caseObject!.path);
    }
  }

  Future<void> _downloadModelIfNeeded() async {
    bool downloaded = await _modelManager.isModelDownloaded('en-US');
    if (!downloaded) {
      await _modelManager.downloadModel('en-US').then((value) {
        print("Downloaded");
      });
    }
    setState(() {
      recognizer = DigitalInkRecognizer(languageCode: 'en-US');
    });
  }

  Future<void> _loadInkFromFile(String filePath) async {
    try {
      String jsonInk = await widget.fileHelper.loadFromFile(filePath);
      setState(() {
        _ink.fromJson(jsonDecode(jsonInk));
        recognizedText = _ink.recognizedText ?? '';
      });
    } catch (e) {
      print("Error loading ink: $e");
    }
  }

  void _clearPad() {
    setState(() {
      _ink.strokes.clear();
      _points.clear();
      recognizedText = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ink Canvas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveInkNote,
          ),
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: _clearPad,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: GestureDetector(
                onPanStart: (DragStartDetails details) {
                  _ink.strokes.add(DrawStroke());
                },
                onPanUpdate: (DragUpdateDetails details) {
                  setState(() {
                    final RenderObject? object = context.findRenderObject();
                    final localPosition = (object as RenderBox?)
                        ?.globalToLocal(details.localPosition);
                    if (localPosition != null) {
                      _points = List.from(_points)
                        ..add(DrawStrokePoint(
                          x: localPosition.dx,
                          y: localPosition.dy,
                          t: DateTime.now().millisecondsSinceEpoch,
                        ));
                    }
                    if (_ink.strokes.isNotEmpty) {
                      _ink.strokes.last.points = _points.toList();
                    }
                  });
                },
                onPanEnd: (DragEndDetails details) {
                  _points.clear();
                  setState(() {});
                },
                child: CustomPaint(
                  painter: Signature(ink: _ink),
                  size: Size.infinite,
                ),
              ),
            ),
            const Positioned(
                bottom: 10,
                right: 0,
                child: Text('Write on the screen',
                    style: TextStyle(fontSize: 10, color: Colors.grey))),
            (recognizedText.isNotEmpty)
                ? Text(
                    recognizedText,
                    style: const TextStyle(fontSize: 16),
                  )
                : const SizedBox.shrink()
          ],
        ),
      ),
    );
  }

  // Recognize ink using Google ML Kit
  Future<String> _recognizeInk() async {
    final recognizedInkCandidates = recognizer != null
        ? await recognizer?.recognize(_ink.toRecognizerInk())
        : List.empty();
    setState(() {
      recognizedText =
          recognizedInkCandidates != null && recognizedInkCandidates.isNotEmpty
              ? recognizedInkCandidates.first.text
              : '';
    });
    return recognizedText;
  }

  // Save the ink note (ink image or stroke data)
  Future<void> _saveInkNote() async {
    String fileName = 'ink_${widget.caseObject!.id}.json';
    // Save recognized text to DrawInk before saving
    await _recognizeInk().then((recognizedText) async {
      _ink.recognizedText = recognizedText;
      String jsonInk = jsonEncode(_ink);
      final filePath = await widget.fileHelper.saveJsonData(fileName, jsonInk);
      widget.caseObject!.path = filePath;
      widget.caseObject!.title = recognizedText;
      widget.onSave(widget.caseObject!);
      Navigator.pop(context);
    });
  }
}

class DrawInk {
  List<DrawStroke> strokes = [];
  String? recognizedText; // Add this to store the recognized text
  DrawInk({this.recognizedText});

  // Convert JSON to DrawInk
  factory DrawInk.fromJson(Map<String, dynamic> json) {
    return DrawInk(
      recognizedText: json['recognizedText'] as String?,
    )..strokes = (json['strokes'] as List)
        .map((stroke) => DrawStroke.fromJson(stroke))
        .toList();
  }

  Map<String, dynamic> toJson() {
    return {
      'strokes': strokes.map((stroke) => stroke.toJson()).toList(),
      'recognizedText': recognizedText, // Include recognized text in JSON
    };
  }

  Ink toRecognizerInk() {
    Ink recognizerInk = Ink();
    for (var stroke in strokes) {
      Stroke recognizerStroke = Stroke();
      recognizerStroke.points = stroke.points.map((point) {
        return StrokePoint(x: point.x, y: point.y, t: point.t);
      }).toList();
      recognizerInk.strokes.add(recognizerStroke);
    }
    return recognizerInk;
  }

  void fromJson(Map<String, dynamic> json) {
    strokes = (json['strokes'] as List)
        .map((stroke) => DrawStroke.fromJson(stroke))
        .toList();
    recognizedText = json['recognizedText'] as String?;
  }
}

class DrawStroke {
  List<DrawStrokePoint> points = [];

  DrawStroke();

  // Convert JSON to DrawStroke
  factory DrawStroke.fromJson(Map<String, dynamic> json) {
    return DrawStroke()
      ..points = (json['points'] as List)
          .map((point) => DrawStrokePoint.fromJson(point))
          .toList();
  }

  Map<String, dynamic> toJson() {
    return {
      'points': points.map((point) => point.toJson()).toList(),
    };
  }
}

class DrawStrokePoint {
  double x;
  double y;
  int t; // timestamp

  DrawStrokePoint({required this.x, required this.y, required this.t});

  // Convert JSON to DrawStrokePoint
  factory DrawStrokePoint.fromJson(Map<String, dynamic> json) {
    return DrawStrokePoint(
      x: json['x'],
      y: json['y'],
      t: json['t'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'x': x,
      'y': y,
      't': t,
    };
  }
}

class Signature extends CustomPainter {
  DrawInk ink;

  Signature({required this.ink});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.blue
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4.0;

    for (final stroke in ink.strokes) {
      for (int i = 0; i < stroke.points.length - 1; i++) {
        final p1 = stroke.points[i];
        final p2 = stroke.points[i + 1];
        canvas.drawLine(Offset(p1.x.toDouble(), p1.y.toDouble()),
            Offset(p2.x.toDouble(), p2.y.toDouble()), paint);
      }
    }
  }

  @override
  bool shouldRepaint(Signature oldDelegate) => true;
}
