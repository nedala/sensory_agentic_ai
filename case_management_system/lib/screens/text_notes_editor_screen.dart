import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../utils/file_helper.dart';
import '../models/case_model.dart';

class TextNoteEditorScreen extends StatefulWidget {
  final CaseObject? caseObject; // Null for new notes
  final Function(CaseObject object) onSave; // Callback when the note is saved
  final String caseId; // The ID of the parent case

  const TextNoteEditorScreen({
    super.key,
    this.caseObject,
    required this.onSave,
    required this.caseId,
  });

  @override
  _TextNoteEditorScreenState createState() => _TextNoteEditorScreenState();
}

class _TextNoteEditorScreenState extends State<TextNoteEditorScreen> {
  late TextEditingController _textController;
  final FileHelper fileHelper = FileHelper();
  final Uuid uuid = const Uuid();
  bool get isNewNote => widget.caseObject == null;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    if (!isNewNote) {
      _loadExistingNote();
    }
  }

  // Load the existing note from the file
  void _loadExistingNote() async {
    final content = await fileHelper.loadFromFile(widget.caseObject!.path);
    setState(() {
      _textController.text = content;
    });
  }

  Future<void> _cancelOut() async {
    Navigator.pop(context);
  }

  Future<void> _saveNote() async {
    final content = _textController.text.trim();

    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Note content cannot be empty')),
      );
      return;
    }

    String fileName;
    String filePath;

    if (isNewNote) {
      // Generate a unique filename for new notes
      fileName = 'note_${uuid.v4()}';
      filePath = await fileHelper.saveJsonData(fileName, content);
    } else {
      // Use the existing filename for editing notes
      fileName = widget.caseObject!.path.split('/').last.replaceAll('.txt', '');
      filePath = await fileHelper.saveJsonData(fileName, content);
    }

    final newObject = CaseObject(
      id: widget.caseObject?.id ?? uuid.v4(),
      caseId: widget.caseId,
      title: 'Text Note',
      path: filePath,
      content: content,
      createdAt: DateTime.now(),
      type: CaseObjectType.textNote,
      isBinaryFile: false,
    );

    widget.onSave(newObject);
    Navigator.pop(context, newObject);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isNewNote ? 'New Note' : 'Edit Note'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveNote, // Save the note when the save icon is pressed
          ),
          IconButton(
            icon: const Icon(Icons.cancel),
            onPressed: _cancelOut, // Leave the note editor without saving
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: TextField(
          controller: _textController,
          maxLines: null, // Allow for multiline
          expands: true, // Expand to take available space
          keyboardType: TextInputType.multiline,
          textAlignVertical: TextAlignVertical.top, // Start text from the top
          decoration: InputDecoration(
            hintText: 'Enter your note here...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.0),
            ),
          ),
        ),
      ),
      floatingActionButton: Align(
        alignment: Alignment.bottomRight, // Align the FABs to the bottom right
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            SizedBox(
              width: 200, // Set a fixed width for the first FAB
              child: FloatingActionButton.extended(
                onPressed: _saveNote,
                label: const Text('Save and Close'),
                icon: const Icon(Icons.save_outlined),
                tooltip:
                    'Save the Text Note', // Show a tooltip when the FAB is long pressed
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: 200, // Set a fixed width for the second FAB
              child: FloatingActionButton.extended(
                onPressed: _cancelOut,
                label: const Text('Leave without saving'),
                icon: const Icon(Icons.cancel_outlined),
                tooltip: 'Leave without saving',
              ),
            )
          ],
        ),
      ),
    );
  }
}
