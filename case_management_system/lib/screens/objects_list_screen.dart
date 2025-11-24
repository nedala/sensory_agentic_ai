import 'dart:collection';
import 'dart:convert';

import 'package:case_management_system/screens/contacts_screen.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path/path.dart' as path;
import 'package:pdfx/pdfx.dart';
import 'package:uuid/uuid.dart';
import 'package:open_file_plus/open_file_plus.dart';
import 'dart:typed_data';
import 'package:image_editor_plus/image_editor_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'dart:io' as io;
import 'dart:async';
import 'package:path/path.dart' as path;
import 'package:image/image.dart' as img;

import '../models/case_model.dart';
import '../utils/db_helper.dart';
import '../utils/file_helper.dart';
import '../utils/pdf_overlay.dart';
import './text_notes_editor_screen.dart';
import './ink_objects.dart';

abstract class CaseObjectHandler {
  Widget buildListItem(BuildContext context, int index, bool isSelected,
      String caseId, CaseObject object);
  Future<void> openEditor(
      BuildContext context, String caseId, CaseObject? object);
  Future<void> openViewer(
      BuildContext context, String caseId, CaseObject object);
  Widget previewObject(BuildContext context, String caseId, CaseObject object);
  Future<void> deleteObject(
      BuildContext context, String caseId, CaseObject object);
  void shareObject(BuildContext context, String caseId, CaseObject object);
  String getObjectTypeTitle();
  Widget _buildFAB(BuildContext context);
  Widget _buildNavigationBar(BuildContext context);
}

enum EventType { Add, Update, Delete }

abstract class BaseCaseObjectHandler extends StatefulWidget
    implements CaseObjectHandler {
  final Case caseEntity;
  final bool isSelected;
  final Function(CaseObject) onToggleSelect;
  final Function(CaseObject, EventType) onUpdate;
  final DatabaseHelper dbHelper;
  final FileHelper fileHelper;
  final CaseObjectType caseObjectType;
  final int selectedIndex;
  const BaseCaseObjectHandler({
    super.key,
    required this.caseEntity,
    required this.isSelected,
    required this.onToggleSelect,
    required this.onUpdate,
    required this.dbHelper,
    required this.fileHelper,
    this.caseObjectType = CaseObjectType.All,
    this.selectedIndex = 0,
  });

  @override
  _BaseCaseStateHandler createState() => _BaseCaseStateHandler();

  @override
  Widget buildListItem(BuildContext context, int index, bool isSelected,
      String caseId, CaseObject object) {
    final String contents = object.content;
    final formattedDate =
        DateFormat('MMM dd, yyyy hh:mm').format(object.createdAt);
    return GestureDetector(
      onTap: () async => await openViewer(context, caseId, object),
      child: Slidable(
        key: ValueKey(object.id),
        startActionPane: ActionPane(
          motion: const StretchMotion(),
          children: [
            SlidableAction(
              onPressed: (context) => shareObject(context, caseId, object),
              icon: Icons.share,
              label: 'Share',
              backgroundColor: Colors.blue,
            ),
          ],
        ),
        endActionPane: ActionPane(
          motion: const StretchMotion(),
          children: [
            SlidableAction(
              onPressed: (context) => deleteObject(context, caseId, object)
                  .then((_) => onUpdate(object, EventType.Delete)),
              icon: Icons.delete,
              label: 'Delete',
              backgroundColor: Colors.red,
            ),
          ],
        ),
        child: Card(
          clipBehavior: Clip.antiAlias,
          elevation: 4.0,
          color: isSelected ? Colors.blue.withOpacity(0.3) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          margin: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Image Section with Hero and Overlay for Created Time and Title
              Stack(
                children: [
                  // Background Image for the Card
                  Hero(
                    tag: 'notes-image-${object.id}',
                    child: Container(
                      height: 128.0,
                      foregroundDecoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.6),
                          ],
                        ),
                      ),
                      child: previewObject(context, caseId, object),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        formattedDate,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        _getObjectTypeTitle(object.type),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(
                height: 8.0,
              ),
              Padding(
                padding: const EdgeInsets.all(2.0),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildActionIcon(FontAwesomeIcons.shareAlt, "Share", () {
                        shareObject(context, caseId, object);
                      }),
                      const SizedBox(width: 6),
                      _buildActionIcon(FontAwesomeIcons.trashAlt, "Delete", () {
                        deleteObject(context, caseId, object)
                            .then((_) => onUpdate(object, EventType.Delete));
                      }),
                      const SizedBox(width: 6),
                      _buildActionIcon(
                          isSelected
                              ? FontAwesomeIcons.solidCheckCircle
                              : FontAwesomeIcons.circle,
                          "Toggle", () {
                        onToggleSelect(object);
                      }),
                    ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionIcon(IconData icon, String label, Function() onTap) {
    return GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            FaIcon(icon, size: 12, color: Colors.blue),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: Colors.black),
            ),
          ],
        ));
  }

  @override
  Future<void> deleteObject(
      BuildContext context, String caseId, CaseObject object) async {
    String objectType = getObjectTypeTitle().toLowerCase();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Note'),
        content: Text('Are you sure you want to delete this $objectType?'),
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
      await dbHelper.deleteCaseObject(object.id);
      if (object.isBinaryFile) {
        await fileHelper.deleteFile(object.path);
      }
      onUpdate(object, EventType.Delete);
    }
  }

  @override
  void shareObject(BuildContext context, String caseId, CaseObject object) {
    throw UnimplementedError();
  }

  @override
  Future<void> openEditor(
      BuildContext context, String caseId, CaseObject? object) {
    throw UnimplementedError();
  }

  @override
  Future<void> openViewer(
      BuildContext context, String caseId, CaseObject object) {
    throw UnimplementedError();
  }

  @override
  Widget previewObject(BuildContext context, String caseId, CaseObject object) {
    throw UnimplementedError();
  }

  @override
  Widget _buildFAB(BuildContext context) {
    throw UnimplementedError();
  }

  void _onItemTapped(context, int index) {
    // Based on the selected index, navigate to the corresponding screen
    switch (index) {
      case 0:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ObjectsListScreen(
              caseEntity: caseEntity,
              caseObjectType: CaseObjectType.All,
              dbHelper: dbHelper,
              fileHelper: fileHelper,
            ),
          ),
        );
        break;
      case 1:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ObjectsListScreen(
              caseEntity: caseEntity,
              caseObjectType: CaseObjectType.textNote,
              dbHelper: dbHelper,
              fileHelper: fileHelper,
            ),
          ),
        );
        break;
      case 2:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ObjectsListScreen(
              caseEntity: caseEntity,
              caseObjectType: CaseObjectType.voiceMemo,
              dbHelper: dbHelper,
              fileHelper: fileHelper,
            ),
          ),
        );
        break;
      case 3:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ObjectsListScreen(
              caseEntity: caseEntity,
              caseObjectType: CaseObjectType.contact,
              dbHelper: dbHelper,
              fileHelper: fileHelper,
            ),
          ),
        );
        break;
      case 4:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ObjectsListScreen(
              caseEntity: caseEntity,
              caseObjectType: CaseObjectType.inkNote,
              dbHelper: dbHelper,
              fileHelper: fileHelper,
            ),
          ),
        );
        break;
      case 5:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ObjectsListScreen(
              caseEntity: caseEntity,
              caseObjectType: CaseObjectType.picture,
              dbHelper: dbHelper,
              fileHelper: fileHelper,
            ),
          ),
        );
        break;
      case 6:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ObjectsListScreen(
              caseEntity: caseEntity,
              caseObjectType: CaseObjectType.attachment,
              dbHelper: dbHelper,
              fileHelper: fileHelper,
            ),
          ),
        );
        break;
    }
  }

  @override
  Widget _buildNavigationBar(BuildContext context) {
    return BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.list),
            label: 'All Items',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notes),
            label: 'Text Notes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.mic),
            label: 'Voice Memos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.contacts),
            label: 'Contacts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.brush),
            label: 'Ink Notes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.photo),
            label: 'Pictures',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.attach_file),
            label: 'Attachments',
          ),
        ],
        currentIndex: selectedIndex,
        selectedItemColor:
            Colors.blue, // Highlighted color for the selected item
        unselectedItemColor: Colors.grey, // Color for unselected items
        onTap: (index) => {_onItemTapped(context, index)});
  }

  @override
  String _getObjectTypeTitle(CaseObjectType caseObjectType) {
    switch (caseObjectType) {
      case CaseObjectType.textNote:
        return 'Text Note';
      case CaseObjectType.picture:
        return 'Picture';
      case CaseObjectType.attachment:
        return 'Attachment';
      case CaseObjectType.voiceMemo:
        return 'Voice Memo';
      case CaseObjectType.contact:
        return 'Contact';
      case CaseObjectType.inkNote:
        return 'Ink Note';
      default:
        return 'Item';
    }
  }

  @override
  String getObjectTypeTitle() {
    return _getObjectTypeTitle(caseObjectType);
  }
}

class _BaseCaseStateHandler extends State<BaseCaseObjectHandler> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    throw UnimplementedError();
  }
}

class ObjectsListScreen extends StatefulWidget {
  final Case caseEntity;
  final CaseObjectType caseObjectType;
  final DatabaseHelper dbHelper;
  final FileHelper fileHelper;

  const ObjectsListScreen({
    super.key,
    required this.caseEntity,
    required this.caseObjectType,
    required this.dbHelper,
    required this.fileHelper,
  });

  @override
  _ObjectsListScreenState createState() => _ObjectsListScreenState();
}

class _ObjectsListScreenState extends State<ObjectsListScreen> {
  List<CaseObject> caseObjects = [];
  List<CaseObject> selectedObjects = [];
  bool isSelectionMode = false;
  HashMap<CaseObjectType, BaseCaseObjectHandler?> handlers =
      HashMap<CaseObjectType, BaseCaseObjectHandler?>();

  @override
  void initState() {
    super.initState();
    _refreshList();
  }

  // Confirm deletion
  Future<void> _confirmDeleteObjects() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Selected Objects'),
          content: Text(
              'Are you sure you want to delete ${selectedObjects.length} items?'),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.pop(
                    context, false); // Return false when cancel is pressed
              },
            ),
            TextButton(
              child: const Text('Confirm'),
              onPressed: () {
                Navigator.pop(
                    context, true); // Return true when delete is pressed
              },
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      // If the user confirmed, proceed with deletion
      await _deletedSelectedObjects();
    }
  }

  // Delete selected cases
  Future<void> _deletedSelectedObjects() async {
    if (selectedObjects.isNotEmpty) {
      for (CaseObject caseObject in selectedObjects) {
        await widget.dbHelper.deleteCaseObject(caseObject.id);
        if (caseObject.isBinaryFile) {
          await widget.fileHelper.deleteFile(caseObject.path);
        }
      }
      setState(() {
        caseObjects.removeWhere((c) => selectedObjects.contains(c));
        selectedObjects.clear();
        isSelectionMode = false;
      });
    }
  }

  // Build empty state with tooltip message
  Widget _buildEmptyState() {
    final typeHandler = _getHandler(widget.caseObjectType);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Card(
          elevation: 5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Hero image
                  Image.asset(
                    'images/empty_box.jpg',
                    height: 200,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'No ${_getHandler(widget.caseObjectType)!.getObjectTypeTitle()} to display.\nPlease create one.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final typeHandler = _getHandler(widget.caseObjectType);
    if (typeHandler == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.caseEntity.title),
        ),
        body: const Center(
          child: Text('No handler available for this object type.'),
        ),
      );
    }
    String title = typeHandler.getObjectTypeTitle();
    isSelectionMode = selectedObjects.isNotEmpty;
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, caseObjects);
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.grey[200],
        appBar: AppBar(
          title: isSelectionMode
              ? Text(
                  '${selectedObjects.length} $title selected in ${widget.caseEntity.title}')
              : Text(
                  '${caseObjects.length} $title in ${widget.caseEntity.title}'),
          actions: isSelectionMode
              ? [
                  IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: _confirmDeleteObjects,
                  ),
                  IconButton(
                    icon: const Icon(Icons.share),
                    onPressed: () => {}, // To do later
                  ),
                ]
              : [
                  caseObjects.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.select_all),
                          onPressed: () {
                            setState(() {
                              selectedObjects.clear();
                              selectedObjects.addAll(caseObjects);
                              isSelectionMode = selectedObjects.isNotEmpty;
                            });
                          },
                        )
                      : const SizedBox.shrink()
                ],
          leading: isSelectionMode
              ? IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    setState(() {
                      isSelectionMode = false;
                      selectedObjects.clear();
                    });
                  },
                )
              : null,
        ),
        body: caseObjects.isEmpty
            ? _buildEmptyState()
            : GridView.builder(
                padding: const EdgeInsets.only(left: 12, right: 12),
                shrinkWrap: true,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 8,
                  mainAxisExtent: 204,
                ),
                itemCount: caseObjects.length,
                itemBuilder: (context, index) {
                  final object = caseObjects[index];
                  final handler = _getHandler(object.type);
                  return (handler ?? typeHandler).buildListItem(
                      context,
                      index,
                      selectedObjects.contains(object),
                      widget.caseEntity.id,
                      object);
                },
              ),
        bottomNavigationBar: typeHandler._buildNavigationBar(context),
        floatingActionButton: typeHandler._buildFAB(context),
      ),
    );
  }

  void _refreshList() async {
    List<CaseObject> updatedObjects =
        await widget.dbHelper.getCaseObjectsByCaseId(widget.caseEntity.id);
    setState(() {
      caseObjects = widget.caseObjectType != CaseObjectType.All
          ? updatedObjects
              .where((o) => o.type == widget.caseObjectType)
              .toList()
          : updatedObjects;
    });
  }

  BaseCaseObjectHandler? _getHandler(CaseObjectType type) {
    if (handlers.containsKey(type)) {
      return handlers[type];
    } else {
      final handler = _createHandler(type);
      handlers[type] = handler;
      return handler;
    }
  }

  BaseCaseObjectHandler? _createHandler(CaseObjectType type) {
    switch (type) {
      case CaseObjectType.textNote:
        return TextNoteHandler(
          caseEntity: widget.caseEntity,
          isSelected: false,
          onToggleSelect: (caseObject) {
            setState(() {
              if (selectedObjects.contains(caseObject)) {
                selectedObjects.remove(caseObject);
              } else {
                selectedObjects.add(caseObject);
              }
              isSelectionMode = selectedObjects.isNotEmpty;
            });
          },
          onUpdate: (caseObject, eventType) {
            setState(() {
              if (eventType == EventType.Delete &&
                  caseObjects.contains(caseObject)) {
                caseObjects.remove(caseObject);
                if (selectedObjects.contains(caseObject)) {
                  selectedObjects.remove(caseObject);
                }
                isSelectionMode = selectedObjects.isNotEmpty;
              } else if (eventType == EventType.Add &&
                  !caseObjects.contains(caseObject)) {
                caseObjects.add(caseObject);
              } else if (eventType == EventType.Update &&
                  caseObjects.contains(caseObject)) {
                caseObjects.removeWhere((c) => c.id == caseObject.id);
                caseObjects.add(caseObject);
                if (selectedObjects.contains(caseObject)) {
                  selectedObjects.removeWhere((c) => c.id == caseObject.id);
                  selectedObjects.add(caseObject);
                }
              }
            });
            _refreshList();
          },
          dbHelper: widget.dbHelper,
          fileHelper: widget.fileHelper,
        );
        break;
      case CaseObjectType.picture:
        return PhotoHandler(
          caseEntity: widget.caseEntity,
          isSelected: false,
          onToggleSelect: (caseObject) {
            setState(() {
              if (selectedObjects.contains(caseObject)) {
                selectedObjects.remove(caseObject);
              } else {
                selectedObjects.add(caseObject);
              }
              isSelectionMode = selectedObjects.isNotEmpty;
            });
          },
          onUpdate: (caseObject, eventType) {
            setState(() {
              if (eventType == EventType.Delete &&
                  caseObjects.contains(caseObject)) {
                caseObjects.remove(caseObject);
                if (selectedObjects.contains(caseObject)) {
                  selectedObjects.remove(caseObject);
                }
                isSelectionMode = selectedObjects.isNotEmpty;
              } else if (eventType == EventType.Add &&
                  !caseObjects.contains(caseObject)) {
                caseObjects.add(caseObject);
              } else if (eventType == EventType.Update &&
                  caseObjects.contains(caseObject)) {
                caseObjects.removeWhere((c) => c.id == caseObject.id);
                caseObjects.add(caseObject);
                if (selectedObjects.contains(caseObject)) {
                  selectedObjects.removeWhere((c) => c.id == caseObject.id);
                  selectedObjects.add(caseObject);
                }
              }
              _refreshList();
            });
          },
          dbHelper: widget.dbHelper,
          fileHelper: widget.fileHelper,
        );
        break;
      case CaseObjectType.attachment:
        return AttachmentHandler(
          caseEntity: widget.caseEntity,
          isSelected: false,
          onToggleSelect: (caseObject) {
            setState(() {
              if (selectedObjects.contains(caseObject)) {
                selectedObjects.remove(caseObject);
              } else {
                selectedObjects.add(caseObject);
              }
              isSelectionMode = selectedObjects.isNotEmpty;
            });
          },
          onUpdate: (caseObject, eventType) {
            setState(() {
              if (eventType == EventType.Delete &&
                  caseObjects.contains(caseObject)) {
                caseObjects.remove(caseObject);
                if (selectedObjects.contains(caseObject)) {
                  selectedObjects.remove(caseObject);
                }
                isSelectionMode = selectedObjects.isNotEmpty;
              } else if (eventType == EventType.Add &&
                  !caseObjects.contains(caseObject)) {
                caseObjects.add(caseObject);
              } else if (eventType == EventType.Update &&
                  caseObjects.contains(caseObject)) {
                caseObjects.removeWhere((c) => c.id == caseObject.id);
                caseObjects.add(caseObject);
                if (selectedObjects.contains(caseObject)) {
                  selectedObjects.removeWhere((c) => c.id == caseObject.id);
                  selectedObjects.add(caseObject);
                }
              }
            });
            _refreshList();
          },
          dbHelper: widget.dbHelper,
          fileHelper: widget.fileHelper,
        );
        break;
      case CaseObjectType.voiceMemo:
        return VoiceMemoHandler(
          caseEntity: widget.caseEntity,
          isSelected: false,
          onToggleSelect: (caseObject) {
            setState(() {
              if (selectedObjects.contains(caseObject)) {
                selectedObjects.remove(caseObject);
              } else {
                selectedObjects.add(caseObject);
              }
              isSelectionMode = selectedObjects.isNotEmpty;
            });
          },
          onUpdate: (caseObject, eventType) {
            setState(() {
              if (eventType == EventType.Delete &&
                  caseObjects.contains(caseObject)) {
                caseObjects.remove(caseObject);
                if (selectedObjects.contains(caseObject)) {
                  selectedObjects.remove(caseObject);
                }
                isSelectionMode = selectedObjects.isNotEmpty;
              } else if (eventType == EventType.Add &&
                  !caseObjects.contains(caseObject)) {
                caseObjects.add(caseObject);
              } else if (eventType == EventType.Update &&
                  caseObjects.contains(caseObject)) {
                caseObjects.removeWhere((c) => c.id == caseObject.id);
                caseObjects.add(caseObject);
                if (selectedObjects.contains(caseObject)) {
                  selectedObjects.removeWhere((c) => c.id == caseObject.id);
                  selectedObjects.add(caseObject);
                }
              }
            });
            _refreshList();
          },
          dbHelper: widget.dbHelper,
          fileHelper: widget.fileHelper,
        );
        break;
      case CaseObjectType.contact:
        return ContactsHandler(
          caseEntity: widget.caseEntity,
          isSelected: false,
          onToggleSelect: (caseObject) {
            setState(() {
              if (selectedObjects.contains(caseObject)) {
                selectedObjects.remove(caseObject);
              } else {
                selectedObjects.add(caseObject);
              }
              isSelectionMode = selectedObjects.isNotEmpty;
            });
          },
          onUpdate: (caseObject, eventType) {
            setState(
              () {
                if (eventType == EventType.Delete &&
                    caseObjects.contains(caseObject)) {
                  caseObjects.remove(caseObject);
                  if (selectedObjects.contains(caseObject)) {
                    selectedObjects.remove(caseObject);
                  }
                  isSelectionMode = selectedObjects.isNotEmpty;
                } else if (eventType == EventType.Add &&
                    !caseObjects.contains(caseObject)) {
                  caseObjects.add(caseObject);
                } else if (eventType == EventType.Update &&
                    caseObjects.contains(caseObject)) {
                  caseObjects.removeWhere((c) => c.id == caseObject.id);
                  caseObjects.add(caseObject);
                  if (selectedObjects.contains(caseObject)) {
                    selectedObjects.removeWhere((c) => c.id == caseObject.id);
                    selectedObjects.add(caseObject);
                  }
                }
              },
            );
            _refreshList();
          },
          dbHelper: widget.dbHelper,
          fileHelper: widget.fileHelper,
        );
        break;
      case CaseObjectType.inkNote:
        return InkNoteHandler(
          caseEntity: widget.caseEntity,
          isSelected: false,
          onToggleSelect: (caseObject) {
            setState(() {
              if (selectedObjects.contains(caseObject)) {
                selectedObjects.remove(caseObject);
              } else {
                selectedObjects.add(caseObject);
              }
              isSelectionMode = selectedObjects.isNotEmpty;
            });
          },
          onUpdate: (caseObject, eventType) {
            setState(() {
              if (eventType == EventType.Delete &&
                  caseObjects.contains(caseObject)) {
                caseObjects.remove(caseObject);
                if (selectedObjects.contains(caseObject)) {
                  selectedObjects.remove(caseObject);
                }
                isSelectionMode = selectedObjects.isNotEmpty;
              } else if (eventType == EventType.Add &&
                  !caseObjects.contains(caseObject)) {
                caseObjects.add(caseObject);
              } else if (eventType == EventType.Update &&
                  caseObjects.contains(caseObject)) {
                caseObjects.removeWhere((c) => c.id == caseObject.id);
                caseObjects.add(caseObject);
                if (selectedObjects.contains(caseObject)) {
                  selectedObjects.removeWhere((c) => c.id == caseObject.id);
                  selectedObjects.add(caseObject);
                }
              }
            });
            _refreshList();
          },
          dbHelper: widget.dbHelper,
          fileHelper: widget.fileHelper,
        );
        break;
      default:
        return AllObjectHandler(
          caseEntity: widget.caseEntity,
          isSelected: false,
          onToggleSelect: (caseObject) {
            setState(() {
              if (selectedObjects.contains(caseObject)) {
                selectedObjects.remove(caseObject);
              } else {
                selectedObjects.add(caseObject);
              }
              isSelectionMode = selectedObjects.isNotEmpty;
            });
          },
          onUpdate: (caseObject, eventType) {
            setState(
              () {
                if (eventType == EventType.Delete &&
                    caseObjects.contains(caseObject)) {
                  caseObjects.remove(caseObject);
                  if (selectedObjects.contains(caseObject)) {
                    selectedObjects.remove(caseObject);
                  }
                  isSelectionMode = selectedObjects.isNotEmpty;
                } else if (eventType == EventType.Add &&
                    !caseObjects.contains(caseObject)) {
                  caseObjects.add(caseObject);
                } else if (eventType == EventType.Update &&
                    caseObjects.contains(caseObject)) {
                  caseObjects.removeWhere((c) => c.id == caseObject.id);
                  caseObjects.add(caseObject);
                  if (selectedObjects.contains(caseObject)) {
                    selectedObjects.removeWhere((c) => c.id == caseObject.id);
                    selectedObjects.add(caseObject);
                  }
                }
              },
            );
            _refreshList();
          },
          dbHelper: widget.dbHelper,
          fileHelper: widget.fileHelper,
        );
    }
  }
}

class ContactsHandler extends BaseCaseObjectHandler
    implements CaseObjectHandler {
  final Uuid uuid = const Uuid();
  const ContactsHandler(
      {super.key,
      required caseEntity,
      required isSelected,
      required onToggleSelect,
      required onUpdate,
      required dbHelper,
      required fileHelper})
      : super(
          caseEntity: caseEntity,
          isSelected: isSelected,
          onToggleSelect: onToggleSelect,
          onUpdate: onUpdate,
          dbHelper: dbHelper,
          fileHelper: fileHelper,
          caseObjectType: CaseObjectType.contact,
          selectedIndex: 3,
        );

  Future<void> editContact(CaseObject caseObject) async {
    Contact? updatedContact =
        ContactJSONSafe.fromJson(jsonDecode(caseObject.content)).toContact();
    try {
      Contact? existingContact =
          await FlutterContacts.getContact(updatedContact.id);
      if (existingContact == null) {
        // If the contact does not exist, create a new one
        updatedContact =
            await FlutterContacts.openExternalInsert(updatedContact);
      }
      // If the contact exists, open the external editor
      else {
        updatedContact =
            await FlutterContacts.openExternalEdit(updatedContact.id) ??
                updatedContact;
      }
    } catch (e) {
      // If an error occurs, retrieve the contact from the JSON content in caseObject
    }
    if (updatedContact != null && updatedContact.displayName.isNotEmpty) {
      caseObject.path = '';
      caseObject.isBinaryFile = false;
      caseObject.content =
          jsonEncode(ContactJSONSafe.fromContact(updatedContact).toJson());
      await dbHelper.updateCaseObject(caseObject);
      onUpdate(caseObject, EventType.Update);
    }
  }

  Future<void> addContact(CaseObject caseObject) async {
    Contact? contact = Contact();
    Contact? updatedContact = await FlutterContacts.openExternalInsert(contact);
    if (updatedContact != null && updatedContact.displayName.isNotEmpty) {
      caseObject.path = '';
      caseObject.isBinaryFile = false;
      caseObject.content =
          jsonEncode(ContactJSONSafe.fromContact(updatedContact).toJson());
      await dbHelper.insertCaseObject(caseObject);
      onUpdate(caseObject, EventType.Add);
    }
  }

  Future<void> importContact(CaseObject caseObject) async {
    Contact? updatedContact = await FlutterContacts.openExternalPick();
    if (updatedContact != null) {
      caseObject.path = '';
      caseObject.isBinaryFile = false;
      caseObject.content =
          jsonEncode(ContactJSONSafe.fromContact(updatedContact).toJson());
      await dbHelper.insertCaseObject(caseObject);
      onUpdate(caseObject, EventType.Add);
    }
  }

  @override
  Future<void> openEditor(
      BuildContext context, String caseId, CaseObject? caseObject) async {
    if (await FlutterContacts.requestPermission(readonly: true)) {
      if (caseObject != null) await editContact(caseObject);
    }
  }

  @override
  Widget previewObject(BuildContext context, String caseId, CaseObject object) {
    return Stack(
      children: [
        // Background image
        Ink.image(
          image: const AssetImage(
              'images/objects/contact_card.jpg'), // Replace with your voice memo image asset
          fit: BoxFit.cover,
          child: InkWell(
            onTap: () {
              openViewer(context, caseId, object);
            },
          ),
        ),
        // Overlay with icon and text content
        Positioned.fill(
          child: Align(
            alignment: Alignment.center,
            child: Container(
              padding: const EdgeInsets.all(8.0),
              color:
                  Colors.black.withOpacity(0.5), // Semi-transparent background
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon representing contact
                  const Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 28,
                  ),
                  const SizedBox(height: 8.0), // Space between icon and text
                  // Title text
                  Text(
                    object.content.isNotEmpty
                        ? '${ContactJSONSafe.fromJson(jsonDecode(object.content)).displayName}'
                        : 'Contact',
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Future<void> openViewer(
      BuildContext context, String caseId, CaseObject object) async {
    openEditor(context, caseId, object);
  }

  @override
  void shareObject(BuildContext context, String caseId, CaseObject object) {
    Share.share('Contact Info: ${object.title}\nDetails: ${object.content}');
  }

  @override
  Widget _buildFAB(BuildContext context) {
    return Stack(
      children: <Widget>[
        Positioned(
          bottom: 80,
          right: 20,
          child: FloatingActionButton.extended(
            heroTag: "importExistingContactFAB",
            onPressed: () => importContact(CaseObject(
                id: uuid.v4(),
                title: "Import Contact",
                caseId: caseEntity.id,
                createdAt: DateTime.now(),
                type: CaseObjectType.contact)),
            tooltip: 'Import Contact',
            icon: const Icon(Icons.import_contacts),
            label: const Text('Import Contact'),
          ),
        ),
        Positioned(
          bottom: 20,
          right: 20,
          child: FloatingActionButton.extended(
            heroTag: "addNewContactFAB",
            onPressed: () => addContact(CaseObject(
                id: uuid.v4(),
                title: "Add Contact",
                caseId: caseEntity.id,
                createdAt: DateTime.now(),
                type: CaseObjectType.contact)),
            tooltip: 'Add Contact',
            icon: const Icon(Icons.person_add),
            label: const Text('Add Contact'),
          ),
        ),
      ],
    );
  }
}

class InkNoteHandler extends BaseCaseObjectHandler
    implements CaseObjectHandler {
  final Uuid uuid = const Uuid();

  const InkNoteHandler({
    super.key,
    required caseEntity,
    required isSelected,
    required onToggleSelect,
    required onUpdate,
    required dbHelper,
    required fileHelper,
  }) : super(
          caseEntity: caseEntity,
          isSelected: isSelected,
          onToggleSelect: onToggleSelect,
          onUpdate: onUpdate,
          dbHelper: dbHelper,
          fileHelper: fileHelper,
          caseObjectType: CaseObjectType.inkNote,
          selectedIndex: 4,
        );

  @override
  Future<void> openEditor(
      BuildContext context, String caseId, CaseObject? object) async {
    bool isNew = object == null;
    object = object ??
        CaseObject(
            id: uuid.v4(),
            title: '',
            caseId: caseId,
            createdAt: DateTime.now(),
            path: '',
            isBinaryFile: true,
            type: CaseObjectType.inkNote);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InkCanvas(
          caseObject: object,
          caseId: caseId,
          fileHelper: fileHelper,
          dbHelper: dbHelper,
          onSave: (updatedObject) async {
            if (isNew) {
              await dbHelper.insertCaseObject(updatedObject);
              onUpdate(updatedObject, EventType.Add);
            } else {
              await dbHelper.updateCaseObject(updatedObject);
              onUpdate(updatedObject, EventType.Update);
            }
          },
        ),
      ),
    );
  }

  @override
  Widget previewObject(BuildContext context, String caseId, CaseObject object) {
    return Stack(
      children: [
        Ink.image(
          image: const AssetImage('images/objects/ink_notes.jpg'),
          fit: BoxFit.cover,
          child: InkWell(
            onTap: () => openViewer(context, caseId, object),
          ),
        ),
        Positioned.fill(
          child: Align(
            alignment: Alignment.center,
            child: Container(
              padding: const EdgeInsets.all(8.0),
              color: Colors.black.withOpacity(0.5),
              child: Text(
                object.title.isNotEmpty ? object.title : 'Ink Note',
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Future<void> openViewer(
      BuildContext context, String caseId, CaseObject object) {
    return openEditor(context, caseId, object);
  }

  @override
  void shareObject(BuildContext context, String caseId, CaseObject object) {
    Share.share('Ink Note: ${object.title}\n${object.content}');
  }

  @override
  Widget _buildFAB(BuildContext context) {
    return FloatingActionButton.extended(
      heroTag: "createNewInkNote",
      onPressed: () => openEditor(context, caseEntity.id, null),
      tooltip: 'Create New Ink Note',
      icon: const Icon(Icons.draw),
      label: const Text('Create Ink Note'),
    );
  }
}

class AllObjectHandler extends BaseCaseObjectHandler
    implements CaseObjectHandler {
  const AllObjectHandler({
    super.key,
    required caseEntity,
    required isSelected,
    required onToggleSelect,
    required onUpdate,
    required dbHelper,
    required fileHelper,
  }) : super(
          caseEntity: caseEntity,
          isSelected: isSelected,
          onToggleSelect: onToggleSelect,
          onUpdate: onUpdate,
          dbHelper: dbHelper,
          fileHelper: fileHelper,
          selectedIndex: 0,
        );

  @override
  Widget _buildFAB(BuildContext context) {
    return const SizedBox.shrink();
  }
}

class TextNoteHandler extends BaseCaseObjectHandler
    implements CaseObjectHandler {
  final Uuid uuid = const Uuid();
  const TextNoteHandler({
    super.key,
    required caseEntity,
    required isSelected,
    required onToggleSelect,
    required onUpdate,
    required dbHelper,
    required fileHelper,
  }) : super(
          caseEntity: caseEntity,
          isSelected: isSelected,
          onToggleSelect: onToggleSelect,
          onUpdate: onUpdate,
          dbHelper: dbHelper,
          fileHelper: fileHelper,
          selectedIndex: 1,
        );

  @override
  Future<void> openEditor(
      BuildContext context, String caseId, CaseObject? object) async {
    CaseObject updatedObject = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TextNoteEditorScreen(
          caseObject: object,
          caseId: caseId,
          onSave: (updatedObject) async {
            if (object == null) {
              // New object
              await dbHelper.insertCaseObject(updatedObject);
              onUpdate(updatedObject, EventType.Add);
            } else {
              // Existing object
              await dbHelper.updateCaseObject(updatedObject);
              onUpdate(updatedObject, EventType.Update);
            }
          },
        ),
      ),
    );
  }

  @override
  Widget previewObject(BuildContext context, String caseId, CaseObject object) {
    return Stack(
      children: [
        // Background image
        Ink.image(
          image: const AssetImage('images/objects/text_notes.png'),
          fit: BoxFit.cover,
          child: InkWell(
            onTap: () {
              // Handle tap if needed
            },
          ),
        ),
        // Overlay with text content
        Positioned.fill(
          child: Align(
            alignment: Alignment.center,
            child: Container(
              padding: const EdgeInsets.all(8.0),
              color:
                  Colors.black.withOpacity(0.5), // Semi-transparent background
              child: Text(
                object.content.isNotEmpty ? object.content : 'Notes',
                textAlign: object.content.isNotEmpty
                    ? TextAlign.left
                    : TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Future<void> openViewer(
      BuildContext context, String caseId, CaseObject object) async {
    await openEditor(context, caseId, object);
  }

  @override
  void shareObject(BuildContext context, String caseId, CaseObject object) {
    // Share the text note content
    fileHelper.loadFromFile(object.path).then((content) {
      Share.share('Title: ${object.title}\n\n$content');
    });
  }

  @override
  Widget _buildFAB(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () => openEditor(context, caseEntity.id, null),
      icon: const Icon(Icons.add),
      tooltip: 'Add Text Note',
      label: const Text('Add Text Note'),
    );
  }
}

class PhotoHandler extends BaseCaseObjectHandler implements CaseObjectHandler {
  final Uuid uuid = const Uuid();
  static final ImagePicker _picker = ImagePicker();
  const PhotoHandler({
    super.key,
    required caseEntity,
    required isSelected,
    required onToggleSelect,
    required onUpdate,
    required dbHelper,
    required fileHelper,
  }) : super(
            caseEntity: caseEntity,
            isSelected: isSelected,
            onToggleSelect: onToggleSelect,
            onUpdate: onUpdate,
            dbHelper: dbHelper,
            fileHelper: fileHelper,
            selectedIndex: 5);

  @override
  Future<void> openEditor(
      BuildContext context, String caseId, CaseObject? caseObject) async {
    if (caseObject != null &&
        caseObject.isBinaryFile &&
        caseObject.path.isNotEmpty) {
      // Load the original image data
      Uint8List imageData = await fileHelper.loadImageData(caseObject.path);

      // Open the image editor and wait for the edited image
      final editedImage = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ImageEditor(
            image: imageData,
          ),
        ),
      );

      if (editedImage != null) {
        // Convert the edited image to JPG format
        img.Image? image = img.decodeImage(editedImage);
        if (image != null) {
          Uint8List jpgData = Uint8List.fromList(img.encodeJpg(image));

          // Save the JPG data back to the CaseObject's path
          await fileHelper.saveBinaryDataFromUint8List(
              path.basename(caseObject.path), jpgData);
          // Update the object in the database
          await dbHelper.updateCaseObject(caseObject);
          onUpdate(caseObject, EventType.Update);
        } else {
          // Handle error if image decoding fails
          print('Failed to decode edited image.');
        }
      }
    }
  }

  Future<void> _pickImage(context, bool useCamera) async {
    final pickedFile = await _picker.pickImage(
      source: useCamera ? ImageSource.camera : ImageSource.gallery,
    );
    if (pickedFile != null) {
      // Convert the image to JPG format
      final imageBytes = await pickedFile.readAsBytes();
      final image = img.decodeImage(imageBytes);
      if (image != null) {
        final jpgData = img.encodeJpg(image, quality: 85);
        // Save the JPG data to the path
        String newId = uuid.v4();
        final path = await fileHelper.saveBinaryDataFromUint8List(
          'photo_$newId.jpg',
          jpgData,
        );

        // Create a new CaseObject for the image
        final newObject = CaseObject(
          id: newId,
          caseId: caseEntity.id,
          title: 'Picture',
          path: path,
          content: '',
          createdAt: DateTime.now(),
          type: CaseObjectType.picture,
          isBinaryFile: true,
        );
        await dbHelper.insertCaseObject(newObject);
        onUpdate(newObject, EventType.Add);
      } else {
        // Handle error if image decoding fails
        print('Failed to decode image.');
      }
    } else {
      print('No image selected.');
    }
  }

  @override
  Widget previewObject(BuildContext context, String caseId, CaseObject object) {
    final io.File file = io.File(object.path);
    final ImageProvider imageProvider = file.existsSync()
        ? FileImage(file)
        : const AssetImage('images/objects/photo_notes.jpg');

    return Container(
      height: 128.0, // Fixed height of 96 pixels
      color: Colors.black87, // Gray filler space
      child: Center(
        child: Image(
          image: imageProvider,
          fit: BoxFit.contain, // Preserve aspect ratio
        ),
      ),
    );
  }

  @override
  Future<void> openViewer(
      BuildContext context, String caseId, CaseObject object) async {
    await openEditor(context, caseId, object);
  }

  @override
  void shareObject(BuildContext context, String caseId, CaseObject object) {
    // Share the text note content
    fileHelper.loadFromFile(object.path).then((content) {
      Share.share('Title: ${object.title}\n\n$content');
    });
  }

  @override
  Widget _buildFAB(BuildContext context) {
    return Stack(
      children: <Widget>[
        Positioned(
          bottom: 80,
          right: 20,
          child: FloatingActionButton.extended(
            heroTag: "cameraFAB",
            onPressed: () => _pickImage(context, true),
            tooltip: 'Capture Image',
            icon: const Icon(Icons.camera_alt),
            label: const Text('Capture Camera'),
          ),
        ),
        Positioned(
          bottom: 20,
          right: 20,
          child: FloatingActionButton.extended(
            heroTag: "galleryFAB",
            onPressed: () => _pickImage(context, false),
            tooltip: 'Pick from Gallery',
            icon: const Icon(Icons.photo_library),
            label: const Text('Pick from Gallery'),
          ),
        ),
      ],
    );
  }
}

class AttachmentHandler extends BaseCaseObjectHandler
    implements CaseObjectHandler {
  final Uuid uuid = const Uuid();

  const AttachmentHandler({
    super.key,
    required caseEntity,
    required isSelected,
    required onToggleSelect,
    required onUpdate,
    required dbHelper,
    required fileHelper,
  }) : super(
            caseEntity: caseEntity,
            isSelected: isSelected,
            onToggleSelect: onToggleSelect,
            onUpdate: onUpdate,
            dbHelper: dbHelper,
            fileHelper: fileHelper,
            selectedIndex: 6);

  @override
  Future<void> openEditor(
      BuildContext context, String caseId, CaseObject? object) async {
    // For attachments, there's typically no editing functionality.
    // If object is provided, open it in viewer.
    if (object != null) {
      openViewer(context, caseId, object);
    }
  }

  @override
  Widget previewObject(BuildContext context, String caseId, CaseObject object) {
    final String filePath = object.path;
    final io.File file = io.File(filePath);

    if (filePath.endsWith('.pdf')) {
      // For PDF files, extract thumbnail
      return Container(
          height: 128.0,
          color: Colors.black87,
          child: Center(
              child: FutureBuilder<Image>(
            future: _buildPdfThumbnail(filePath),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done &&
                  snapshot.hasData) {
                return Container(
                  height: 128.0,
                  color: Colors.black87,
                  child: snapshot.data,
                );
              } else if (snapshot.hasError) {
                return _buildFileIconTile(context, object);
              } else {
                return const SizedBox(
                  height: 128.0,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
            },
          )));
    } else if (_isImageFile(filePath)) {
      // If it's an image file, display it
      final ImageProvider imageProvider = file.existsSync()
          ? FileImage(file)
          : const AssetImage('images/objects/file_attachment.jpg');

      return Container(
        height: 128.0,
        color: Colors.black87,
        child: Center(
          child: Image(
            image: imageProvider,
            fit: BoxFit.contain,
          ),
        ),
      );
    } else {
      // For other files, show icon and file name
      return _buildFileIconTile(context, object);
    }
  }

  bool _isImageFile(String filePath) {
    final imageExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.bmp'];
    return imageExtensions.any((ext) => filePath.toLowerCase().endsWith(ext));
  }

  Future<Image> _buildPdfThumbnail(String filePath) async {
    final doc = await PdfDocument.openFile(filePath);
    final page = await doc.getPage(1);
    final pageImage = await page.render(
      width: page.width * 2,
      height: page.height * 2,
      format: PdfPageImageFormat.jpeg, // Use JPEG format for efficiency
      backgroundColor: '#FFFFFF', // White background
    );
    await page.close();
    await doc.close();

    return pageImage != null
        ? Image.memory(
            pageImage.bytes,
            fit: BoxFit.contain,
          )
        : Image.asset('images/objects/pdf_icon.png');
  }

  Widget _buildFileIconTile(BuildContext context, CaseObject object) {
    IconData fileIcon;
    String filePath = object.path;
    String fileType = 'Unknown';
    if (filePath.endsWith('.doc') || filePath.endsWith('.docx')) {
      fileIcon = Icons.description;
      fileType = 'Word Document';
    } else if (filePath.endsWith('.ppt') || filePath.endsWith('.pptx')) {
      fileIcon = Icons.slideshow;
      fileType = 'PowerPoint Presentation';
    } else if (filePath.endsWith('.html')) {
      fileIcon = Icons.web;
      fileType = 'HTML File';
    } else if (filePath.endsWith('.pdf')) {
      fileIcon = Icons.picture_as_pdf;
      fileType = object.content.isNotEmpty ? object.content : 'PDF Document';
    } else {
      fileIcon = Icons.insert_drive_file;
      fileType = 'File';
    }

    return ListTile(
      leading: Icon(fileIcon, size: 40),
      title: Text(fileType),
      subtitle: Text(path.basename(filePath)),
      onTap: () {
        openViewer(context, object.caseId, object);
      },
    );
  }

  @override
  Future<void> openViewer(
      BuildContext context, String caseId, CaseObject object) async {
    try {
      print("Opening file: ${object.path}");
      final result = await OpenFile.open(object.path);
      if (result.type == ResultType.noAppToOpen) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No application found to open this file type.'),
          ),
        );
      } else if (result.type == ResultType.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error opening the file.'),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to open file: $e'),
        ),
      );
    }
  }

  @override
  void shareObject(
      BuildContext context, String caseId, CaseObject object) async {
    // Share the attachment file
    await Share.shareXFiles([XFile(object.path)], text: object.title);
  }

  @override
  Widget _buildFAB(BuildContext context) {
    return Stack(
      children: <Widget>[
        Positioned(
          bottom: 200,
          right: 20,
          child: FloatingActionButton.extended(
            heroTag: "businessCardFAB",
            onPressed: () => _scanPDFDocument(context, true, true),
            tooltip: 'Scan Business Card',
            label: const Text('Business Card'),
            icon: const Icon(Icons.contact_mail),
          ),
        ),
        Positioned(
          bottom: 140,
          right: 20,
          child: FloatingActionButton.extended(
            heroTag: "pdfFABText",
            onPressed: () => _scanPDFDocument(context, false, true),
            tooltip: 'Capture OCR PDF',
            label: const Text('Text PDF'),
            icon: const Icon(Icons.text_format),
          ),
        ),
        Positioned(
          bottom: 80,
          right: 20,
          child: FloatingActionButton.extended(
            heroTag: "pdfFAB",
            onPressed: () => _scanPDFDocument(context, false, false),
            label: const Text('Image PDF'),
            tooltip: 'Capture Image PDF',
            icon: const Icon(Icons.picture_as_pdf),
          ),
        ),
        Positioned(
          bottom: 20,
          right: 20,
          child: FloatingActionButton.extended(
            heroTag: "fileFAB",
            onPressed: () => _pickFile(context),
            tooltip: 'Pick Attachment',
            label: const Text('Attachment'),
            icon: const Icon(Icons.attach_file),
          ),
        ),
      ],
    );
  }

  Future<void> _pickFile(BuildContext context) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      String originalPath = result.files.single.path!;
      String newId = uuid.v4();
      String fileName = path.basename(originalPath);
      String newFileName = 'attachment_${newId}_$fileName';
      String newPath =
          await fileHelper.copyFileToAppDirectory(originalPath, newFileName);

      final newObject = CaseObject(
        id: newId,
        caseId: caseEntity.id,
        title: fileName,
        path: newPath,
        content: '',
        createdAt: DateTime.now(),
        type: CaseObjectType.attachment,
        isBinaryFile: true,
      );
      await dbHelper.insertCaseObject(newObject);
      onUpdate(newObject, EventType.Add);
    }
  }

  Future<void> _scanPDFDocument(
      BuildContext context, bool isBusinessCard, bool addTextOverlay) async {
    try {
      final documentOptions = DocumentScannerOptions(
        documentFormat: DocumentFormat.pdf,
        pageLimit: 64,
        mode: ScannerMode.full,
        isGalleryImport: true,
      );

      final documentScanner = DocumentScanner(options: documentOptions);
      DocumentScanningResult result = await documentScanner.scanDocument();
      documentScanner.close();

      if (result.pdf != null && result.pdf!.pageCount > 0) {
        String newId = uuid.v4();
        String fileName =
            '${isBusinessCard ? 'business_card' : 'scanned_document'}_$newId.pdf';
        String filePath =
            await fileHelper.copyFileToAppDirectory(result.pdf!.uri, fileName);

        // If addTextOverlay is true, we need to perform OCR and create a text overlay PDF
        if (addTextOverlay) {
          filePath = await createTextOverlaidPDF(filePath, fileName);
        }

        final newObject = CaseObject(
          id: newId,
          caseId: caseEntity.id,
          title: fileName,
          path: filePath,
          content: isBusinessCard ? 'Business Card' : 'Scanned Document',
          createdAt: DateTime.now(),
          type: CaseObjectType.attachment,
          isBinaryFile: true,
        );

        await dbHelper.insertCaseObject(newObject);
        onUpdate(newObject, EventType.Add);
      }
    } catch (e) {
      print('Error scanning document: $e');
    }
  }
}

class VoiceMemoHandler extends BaseCaseObjectHandler
    implements CaseObjectHandler {
  final Uuid uuid = const Uuid();

  const VoiceMemoHandler({
    super.key,
    required caseEntity,
    required isSelected,
    required onToggleSelect,
    required onUpdate,
    required dbHelper,
    required fileHelper,
  }) : super(
          caseEntity: caseEntity,
          isSelected: isSelected,
          onToggleSelect: onToggleSelect,
          onUpdate: onUpdate,
          dbHelper: dbHelper,
          fileHelper: fileHelper,
          selectedIndex: 2,
        );

  @override
  Future<void> openEditor(
      BuildContext context, String caseId, CaseObject? object) async {
    // Show the recorder in a modal bottom sheet
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: VoiceMemoRecorderWidget(
            onSave: (newObject) async {
              await dbHelper.insertCaseObject(newObject);
              onUpdate(newObject, EventType.Add);
            },
            caseId: caseId,
            fileHelper: fileHelper,
          ),
        );
      },
    );
  }

  @override
  Widget previewObject(BuildContext context, String caseId, CaseObject object) {
    return Stack(
      children: [
        // Background image
        Ink.image(
          image: const AssetImage(
              'images/objects/voice_notes.jpg'), // Replace with your voice memo image asset
          fit: BoxFit.cover,
          child: InkWell(
            onTap: () {
              openViewer(context, caseId, object);
            },
          ),
        ),
        // Overlay with icon and text content
        Positioned.fill(
          child: Align(
            alignment: Alignment.center,
            child: Container(
              padding: const EdgeInsets.all(8.0),
              color:
                  Colors.black.withOpacity(0.5), // Semi-transparent background
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon representing voice memo
                  const Icon(
                    Icons.mic,
                    color: Colors.white,
                    size: 28,
                  ),
                  const SizedBox(height: 8.0), // Space between icon and text
                  // Title text
                  Text(
                    object.title.isNotEmpty ? object.title : 'Voice Memo',
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Future<void> openViewer(
      BuildContext context, String caseId, CaseObject object) async {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return VoiceMemoPlayerBottomSheet(
          caseObject: object,
        );
      },
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return DateFormat('MMM dd, yyyy hh:mm a').format(dateTime);
  }

  @override
  void shareObject(
      BuildContext context, String caseId, CaseObject object) async {
    // Share the voice memo file
    await Share.shareXFiles([XFile(object.path)], text: object.title);
  }

  @override
  Widget _buildFAB(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () => openEditor(context, caseEntity.id, null),
      icon: const Icon(Icons.mic),
      label: const Text('Record Voice Memo'),
      tooltip: 'Record Voice Memo',
    );
  }
}

class VoiceMemoRecorderWidget extends StatefulWidget {
  final Function(CaseObject) onSave;
  final String caseId;
  final FileHelper fileHelper;

  const VoiceMemoRecorderWidget({
    super.key,
    required this.onSave,
    required this.caseId,
    required this.fileHelper,
  });

  @override
  _VoiceMemoRecorderWidgetState createState() =>
      _VoiceMemoRecorderWidgetState();
}

class _VoiceMemoRecorderWidgetState extends State<VoiceMemoRecorderWidget> {
  FlutterSoundRecorder? _recorder;
  bool _isRecording = false;
  bool _isPaused = false; // Track if recording is paused
  String? _filePath;
  Timer? _timer;
  Duration _recordDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _initializeRecorder();
  }

  @override
  void dispose() {
    _recorder?.closeRecorder();
    _timer?.cancel();
    super.dispose();
  }

  void _initializeRecorder() async {
    _recorder = FlutterSoundRecorder();
    await _recorder!.openRecorder();

    // Request microphone permission
    await Permission.microphone.request();
  }

  Future<void> _startRecording() async {
    // Check microphone permission
    if (await Permission.microphone.isGranted) {
      String newId = const Uuid().v4();
      String fileName = 'voice_memo_$newId.aac';
      String filePath = await widget.fileHelper.getFilePath(fileName);

      await _recorder!.startRecorder(
        toFile: filePath,
        codec: Codec.aacADTS, // Use AAC codec
        bitRate: 128000, // Optional bitrate
        sampleRate: 44100, // Optional sampling rate
      );

      setState(() {
        _isRecording = true;
        _isPaused = false; // Reset pause state when starting recording
        _filePath = filePath;
        _recordDuration = Duration.zero;
      });

      _startTimer();
    } else {
      // Handle permission denied
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Microphone permission is required to record voice memos.'),
        ),
      );
    }
  }

  Future<void> _stopRecording() async {
    await _recorder!.stopRecorder();
    _timer?.cancel();

    setState(() {
      _isRecording = false;
      _isPaused = false;
    });

    // Save the voice memo as a CaseObject
    if (_filePath != null) {
      final newObject = CaseObject(
        id: const Uuid().v4(),
        caseId: widget.caseId,
        title: 'Voice Memo ${_formatDuration(_recordDuration)}',
        path: _filePath!,
        content: '',
        createdAt: DateTime.now(),
        type: CaseObjectType.voiceMemo,
        isBinaryFile: true,
      );
      widget.onSave(newObject);
    }

    // Close the modal or perform any additional actions
    Navigator.pop(context);
  }

  Future<void> _pauseRecording() async {
    await _recorder!.pauseRecorder();
    setState(() {
      _isPaused = true;
    });

    _timer?.cancel(); // Stop the timer when paused
  }

  Future<void> _resumeRecording() async {
    await _recorder!.resumeRecorder();
    setState(() {
      _isPaused = false;
    });

    _startTimer(); // Restart the timer when resumed
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _recordDuration += const Duration(seconds: 1);
      });
    });
  }

  String _formatDuration(Duration duration) {
    return [
      duration.inMinutes.toString().padLeft(2, '0'),
      duration.inSeconds.remainder(60).toString().padLeft(2, '0'),
    ].join(':');
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 12.0),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 12.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _isRecording
                  ? _isPaused
                      ? 'Recording Paused'
                      : 'Recording...'
                  : 'Ready to Record',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (_isRecording)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  _formatDuration(_recordDuration),
                  style: const TextStyle(fontSize: 24, color: Colors.red),
                ),
              ),
            const SizedBox(height: 10),
            // Recording controls
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Start/Stop Button
                ElevatedButton.icon(
                  icon: Icon(_isRecording ? Icons.stop : Icons.mic),
                  label: Text(_isRecording ? 'Stop' : 'Start'),
                  onPressed: _isRecording ? _stopRecording : _startRecording,
                  style: ElevatedButton.styleFrom(
                    foregroundColor: _isRecording ? Colors.red : Colors.green,
                  ),
                ),
                const SizedBox(width: 10),
                // Pause/Resume Button (Visible only during recording)
                if (_isRecording)
                  ElevatedButton.icon(
                    icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
                    label: Text(_isPaused ? 'Resume' : 'Pause'),
                    onPressed: _isPaused ? _resumeRecording : _pauseRecording,
                    style: ElevatedButton.styleFrom(
                      foregroundColor: _isPaused ? Colors.green : Colors.orange,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class VoiceMemoPlayerBottomSheet extends StatefulWidget {
  final CaseObject caseObject;

  const VoiceMemoPlayerBottomSheet({
    super.key,
    required this.caseObject,
  });

  @override
  _VoiceMemoPlayerBottomSheetState createState() =>
      _VoiceMemoPlayerBottomSheetState();
}

class _VoiceMemoPlayerBottomSheetState
    extends State<VoiceMemoPlayerBottomSheet> {
  FlutterSoundPlayer? _player;
  bool _isPlaying = false;
  bool _isPaused = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  StreamSubscription? _playerSubscription;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  @override
  void dispose() {
    _playerSubscription?.cancel();
    _player?.closePlayer();
    super.dispose();
  }

  void _initializePlayer() async {
    _player = FlutterSoundPlayer();
    await _player!.openPlayer();

    // Set the subscription duration to get updates every 0.5 seconds
    await _player!.setSubscriptionDuration(const Duration(milliseconds: 500));

    _playerSubscription = _player!.onProgress!.listen((event) {
      setState(() {
        _position = event.position;
        // Update duration if it's still zero
        if (_duration == Duration.zero) {
          _duration = event.duration;
        }
      });
    });
  }

  Future<void> _startPlaying() async {
    await _player!.startPlayer(
      fromURI: widget.caseObject.path,
      codec: Codec.aacADTS, // Specify the codec if needed
      whenFinished: () {
        setState(() {
          _isPlaying = false;
          _isPaused = false;
          _position = Duration.zero;
        });
        Navigator.pop(context);
      },
    );
    setState(() {
      _isPlaying = true;
      _isPaused = false;
    });
  }

  Future<void> _pausePlaying() async {
    await _player!.pausePlayer();
    setState(() {
      _isPlaying = false;
      _isPaused = true;
    });
  }

  Future<void> _resumePlaying() async {
    await _player!.resumePlayer();
    setState(() {
      _isPlaying = true;
      _isPaused = false;
    });
  }

  String _formatDuration(Duration duration) {
    return [
      duration.inMinutes.remainder(60).toString().padLeft(2, '0'),
      duration.inSeconds.remainder(60).toString().padLeft(2, '0'),
    ].join(':');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      child: Wrap(
        children: [
          Center(
            child: Text(
              widget.caseObject.title.isNotEmpty
                  ? widget.caseObject.title
                  : 'Voice Memo',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 10),
          if (_duration.inMilliseconds > 0)
            Column(
              children: [
                Slider(
                  value: _position.inMilliseconds.toDouble(),
                  max: _duration.inMilliseconds.toDouble(),
                  onChanged: (value) async {
                    final position = Duration(milliseconds: value.toInt());
                    await _player!.seekToPlayer(position);
                  },
                ),
                Text(
                  '${_formatDuration(_position)} / ${_formatDuration(_duration)}',
                  style: TextStyle(fontSize: 14.0, color: Colors.grey[600]),
                ),
              ],
            ),
          const SizedBox(height: 20),
          Center(
            child: ElevatedButton.icon(
              icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
              label: Text(_isPlaying
                  ? 'Pause'
                  : _isPaused
                      ? 'Resume'
                      : 'Play'),
              onPressed: () {
                if (_isPlaying) {
                  _pausePlaying();
                } else if (_isPaused) {
                  _resumePlaying();
                } else {
                  _startPlaying();
                }
              },
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
