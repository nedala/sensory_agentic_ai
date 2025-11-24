import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart'; // For swipe actions
import 'package:intl/intl.dart'; // For formatting timestamps
import 'package:timelines/timelines.dart'; // For better timeline visuals
import '../models/case_model.dart';
import '../utils/file_helper.dart';
import '../utils/db_helper.dart'; // Import the DatabaseHelper
import 'text_notes_editor_screen.dart';
import 'dart:io'; // For working with file timestamps

class TextNotesScreen extends StatefulWidget {
  final Case caseEntity;
  final DatabaseHelper dbHelper;
  final bool isSelectionMode;

  const TextNotesScreen(
      {super.key,
      required this.caseEntity,
      required this.dbHelper,
      this.isSelectionMode = false});

  @override
  _TextNotesScreenState createState() => _TextNotesScreenState();
}

class _TextNotesScreenState extends State<TextNotesScreen> {
  late List<bool> _selectedItems; // Track selected items for deletion
  bool _isSelectionMode = false;
  num _itemsLength = 0;
  final FileHelper _fileHelper = FileHelper();

  @override
  void initState() {
    super.initState();
    _selectedItems = List<bool>.generate(
        widget.caseEntity.textNotes.length, (index) => false);
    _itemsLength = widget.caseEntity.textNotes.length;
  }

  // Toggle selection mode on/off
  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedItems = List<bool>.generate(
            widget.caseEntity.textNotes.length, (index) => false);
      }
      _itemsLength = widget.caseEntity.textNotes.length;
    });
  }

  // Get file creation date (or fallback to current time)
  Future<DateTime> _getFileCreationDate(String filePath) async {
    try {
      final file = File(filePath);
      final stat = await file.stat();
      return stat.changed; // Return file creation date
    } catch (e) {
      return DateTime.now(); // Fallback to current time if file access fails
    }
  }

  // Function to format the DateTime
  String _formatDateTime(DateTime dateTime) {
    return DateFormat('MMM dd, yyyy hh:mm a').format(dateTime);
  }

  // Persist case to SQLite
  void _saveCaseToDatabase() async {
    await widget.dbHelper.updateCase(widget.caseEntity);
  }

  // Delete selected notes
  Future<void> _deleteSelectedNotes() async {
    final confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Notes'),
        content:
            const Text('Are you sure you want to delete the selected notes?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        widget.caseEntity.textNotes =
            List<String>.from(widget.caseEntity.textNotes);
        for (int i = widget.caseEntity.textNotes.length - 1; i >= 0; i--) {
          if (_selectedItems[i]) {
            _fileHelper.deleteFile(widget.caseEntity.textNotes[i]);
            widget.caseEntity.textNotes.removeAt(i);
          }
        }

        _selectedItems = List<bool>.generate(
            widget.caseEntity.textNotes.length, (index) => false);
        _isSelectionMode = false;
        _itemsLength = widget.caseEntity.textNotes.length;
        _saveCaseToDatabase();
      });
    }
  }

  // Delete a single note when swiped
  void _deleteNoteAtIndex(int index) async {
    final confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Note'),
        content: const Text('Are you sure you want to delete this note?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        widget.caseEntity.textNotes =
            List<String>.from(widget.caseEntity.textNotes);
        _fileHelper.deleteFile(widget.caseEntity.textNotes[index]);
        widget.caseEntity.textNotes.removeAt(index);
        _selectedItems.removeAt(index);
        _itemsLength = widget.caseEntity.textNotes.length;
        _saveCaseToDatabase();
      });
    }
  }

  // Callback to add a new note to the case
  void _addNewNoteCallback(String filePath) {
    setState(() {
      widget.caseEntity.textNotes =
          List<String>.from(widget.caseEntity.textNotes);
      widget.caseEntity.textNotes.add(filePath);
      _selectedItems.add(false);
      _itemsLength = widget.caseEntity.textNotes.length;
      _saveCaseToDatabase();
    });
  }

  // Edit an existing note
  void _editNoteCallback(int index, String filePath) {
    setState(() {
      widget.caseEntity.textNotes =
          List<String>.from(widget.caseEntity.textNotes);
      widget.caseEntity.textNotes[index] = filePath;
      _itemsLength = widget.caseEntity.textNotes.length;
      _saveCaseToDatabase();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Text Notes ($_itemsLength)'),
        actions: [
          if (_isSelectionMode)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _deleteSelectedNotes,
            ),
          IconButton(
            icon: Icon(_isSelectionMode ? Icons.cancel : Icons.select_all),
            onPressed: _toggleSelectionMode,
          ),
        ],
      ),
      body: SingleChildScrollView(
        // Make the entire body scrollable
        child: Column(
          children: [
            FixedTimeline.tileBuilder(
              builder: TimelineTileBuilder.connectedFromStyle(
                contentsAlign: ContentsAlign.alternating,
                itemCount: widget.caseEntity.textNotes.length,
                oppositeContentsBuilder: (context, index) {
                  return FutureBuilder<DateTime>(
                    future: _getFileCreationDate(
                        widget.caseEntity.textNotes[index]),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const CircularProgressIndicator();
                      } else if (snapshot.hasData) {
                        return Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            _formatDateTime(snapshot.data!),
                            style: const TextStyle(color: Colors.grey),
                          ),
                        );
                      } else {
                        return const Text("Error fetching date");
                      }
                    },
                  );
                },
                contentsBuilder: (context, index) {
                  return _buildTimelineCard(
                      widget.caseEntity.textNotes[index], index);
                },
                connectorStyleBuilder: (context, index) =>
                    ConnectorStyle.solidLine,
                indicatorStyleBuilder: (context, index) =>
                    IndicatorStyle.outlined,
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _isSelectionMode
          ? null
          : FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TextNoteEditorScreen(
                      onSave: _addNewNoteCallback,
                    ),
                  ),
                );
              },
              child: const Icon(Icons.add),
            ),
    );
  }

  // Build each note card with a timestamp, timeline line, and selection checkbox
  Widget _buildTimelineCard(String notePath, int index) {
    return Padding(
        padding: const EdgeInsets.all(6.0),
        child: Slidable(
          key: ValueKey(notePath),
          startActionPane: ActionPane(
            motion: const ScrollMotion(),
            children: [
              SlidableAction(
                onPressed: (context) => _deleteNoteAtIndex(index),
                icon: Icons.delete,
                label: 'Delete',
                backgroundColor: Colors.red,
              ),
            ],
          ),
          child: GestureDetector(
            onTap: () {
              if (_isSelectionMode) {
                setState(() {
                  _selectedItems[index] = !_selectedItems[index];
                });
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TextNoteEditorScreen(
                      filePath: notePath,
                      onSave: (filePath) => _editNoteCallback(index, filePath),
                    ),
                  ),
                );
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(6.0),
                        child: FutureBuilder<String>(
                          future: _fileHelper.loadTextNoteFromFile(notePath),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                  child: CircularProgressIndicator());
                            }
                            if (snapshot.hasData) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Note ${index + 1}",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    snapshot.data!,
                                    style: const TextStyle(fontSize: 14),
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              );
                            }
                            return const Text('Error loading note');
                          },
                        ),
                      ),
                    ),
                  ),
                  if (_isSelectionMode)
                    Checkbox(
                      value: _selectedItems[index],
                      onChanged: (bool? value) {
                        setState(() {
                          _selectedItems[index] = value!;
                        });
                      },
                    ),
                ],
              ),
            ),
          ),
        ));
  }
}
