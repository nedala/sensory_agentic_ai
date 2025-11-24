import 'package:case_management_system/screens/objects_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'models/case_model.dart';
import '../utils/db_helper.dart';
import '../utils/file_helper.dart';

// Define a list of image paths to rotate through as background images for the cards.
const List<String> assetImages = [
  'images/covers/backimage1.jpg',
  'images/covers/backimage2.jpg',
  'images/covers/backimage3.jpg',
  'images/covers/backimage4.jpg',
  'images/covers/backimage5.jpg',
  'images/covers/backimage6.jpg',
  'images/covers/backimage7.jpg',
  'images/covers/backimage8.jpg',
  'images/covers/backimage9.jpg',
  'images/covers/backimage10.jpg',
  'images/covers/backimage11.jpg',
  'images/covers/backimage12.jpg',
  'images/covers/backimage13.jpg',
  'images/covers/backimage14.jpg',
];

class CaseTile extends StatefulWidget {
  final Case caseEntity;
  final bool isSelected;
  final Function(Case) onRename;
  final Function(Case) onDelete;
  final Function(Case) onShare;
  final Function(Case) onToggleSelect;

  final DatabaseHelper dbHelper;
  final FileHelper fileHelper;

  const CaseTile({
    super.key,
    required this.caseEntity,
    required this.isSelected,
    required this.onRename,
    required this.onDelete,
    required this.onShare,
    required this.onToggleSelect,
    required this.dbHelper,
    required this.fileHelper,
  });

  @override
  _CaseTileState createState() => _CaseTileState();
}

class _CaseTileState extends State<CaseTile> {
  late int textNoteCount;
  late int pictureCount;
  late int attachmentCount;
  late int voiceMemoCount;
  late int contactCount;
  late int inkNoteCount;
  late int allCount;

  @override
  void initState() {
    super.initState();
    textNoteCount = 0;
    pictureCount = 0;
    attachmentCount = 0;
    voiceMemoCount = 0;
    contactCount = 0;
    inkNoteCount = 0;
    allCount = 0;
    _loadCounts();
  }

  void _loadCounts() async {
    List<CaseObject> caseObjects =
        await widget.dbHelper.getCaseObjectsByCaseId(widget.caseEntity.id);

    setState(() {
      textNoteCount =
          caseObjects.where((o) => o.type == CaseObjectType.textNote).length;
      pictureCount =
          caseObjects.where((o) => o.type == CaseObjectType.picture).length;
      attachmentCount =
          caseObjects.where((o) => o.type == CaseObjectType.attachment).length;
      voiceMemoCount =
          caseObjects.where((o) => o.type == CaseObjectType.voiceMemo).length;
      contactCount =
          caseObjects.where((o) => o.type == CaseObjectType.contact).length;
      inkNoteCount =
          caseObjects.where((o) => o.type == CaseObjectType.inkNote).length;
      allCount = caseObjects.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate =
        DateFormat('MMM dd, yyyy').format(widget.caseEntity.createdAt);
    final String backgroundImage =
        assetImages[widget.caseEntity.id.hashCode % assetImages.length];

    return GestureDetector(
      onLongPress: () => widget.onToggleSelect(widget.caseEntity),
      onTap: () {
        if (widget.isSelected) {
          widget.onToggleSelect(widget.caseEntity);
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ObjectsListScreen(
                caseEntity: widget.caseEntity,
                dbHelper: widget.dbHelper,
                fileHelper: widget.fileHelper,
                caseObjectType: CaseObjectType.All,
              ),
            ),
          ).then((_) {
            setState(() {
              _loadCounts();
            });
          });
        }
      },
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: 4.0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.symmetric(vertical: 10),
        color: widget.isSelected ? Colors.blue.withOpacity(0.3) : Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image Section with Hero and Overlay for Created Time and Title
            Stack(
              children: [
                // Background Image for the Card
                Hero(
                  tag: 'hero-image-${widget.caseEntity.id}',
                  child: Container(
                    height: 172.0,
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
                    child: Ink.image(
                      image: AssetImage(backgroundImage),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                // Positioned container for centered title text with background for contrast
                Positioned.fill(
                  child: Center(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8.0, vertical: 4.0),
                      child: Hero(
                        tag: 'title-${widget.caseEntity.id}',
                        child: Text(
                          widget.caseEntity.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                blurRadius: 2.0,
                                color: Colors.black,
                                offset: Offset(1.0, 1.0),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Positioned text at the bottom right corner for Created Time
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    color: Colors.black.withOpacity(0.7),
                    child: Text(
                      formattedDate,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 8,
                  left: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    color: Colors.black.withOpacity(0.7),
                    child: Text(
                      '$allCount items',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                // Share button at the top-right corner
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    icon: Icon(Icons.share,
                        color: widget.isSelected ? Colors.blue : Colors.white),
                    onPressed: () => widget.onShare(widget.caseEntity),
                    tooltip: 'Share this Case',
                  ),
                ),
              ],
            ),
            Container(
                child: Column(children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildObjectCountIcon(Icons.notes, 'Notes', textNoteCount,
                        () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ObjectsListScreen(
                            caseEntity: widget.caseEntity,
                            dbHelper: widget.dbHelper,
                            fileHelper: widget.fileHelper,
                            caseObjectType: CaseObjectType.textNote,
                          ),
                        ),
                      ).then((value) {
                        _loadCounts();
                      });
                    }),
                    _buildObjectCountIcon(Icons.image, 'Pictures', pictureCount,
                        () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ObjectsListScreen(
                            caseEntity: widget.caseEntity,
                            dbHelper: widget.dbHelper,
                            fileHelper: widget.fileHelper,
                            caseObjectType: CaseObjectType.picture,
                          ),
                        ),
                      ).then((value) {
                        _loadCounts(); // Reload counts when returning from detail screen
                      });
                    }),
                    _buildObjectCountIcon(
                        Icons.attach_file, 'Files', attachmentCount, () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ObjectsListScreen(
                            caseEntity: widget.caseEntity,
                            dbHelper: widget.dbHelper,
                            fileHelper: widget.fileHelper,
                            caseObjectType: CaseObjectType.attachment,
                          ),
                        ),
                      ).then((value) {
                        _loadCounts();
                      });
                    }),
                    _buildObjectCountIcon(Icons.mic, 'Voice', voiceMemoCount,
                        () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ObjectsListScreen(
                            caseEntity: widget.caseEntity,
                            dbHelper: widget.dbHelper,
                            fileHelper: widget.fileHelper,
                            caseObjectType: CaseObjectType.voiceMemo,
                          ),
                        ),
                      ).then((value) {
                        _loadCounts();
                      });
                    }),
                    _buildObjectCountIcon(
                        Icons.contact_phone, 'Contacts', contactCount, () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ObjectsListScreen(
                            caseEntity: widget.caseEntity,
                            dbHelper: widget.dbHelper,
                            fileHelper: widget.fileHelper,
                            caseObjectType: CaseObjectType.contact,
                          ),
                        ),
                      ).then((value) {
                        _loadCounts();
                      });
                    }),
                    _buildObjectCountIcon(
                        Icons.brush, 'Ink Notes', inkNoteCount, () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ObjectsListScreen(
                            caseEntity: widget.caseEntity,
                            dbHelper: widget.dbHelper,
                            fileHelper: widget.fileHelper,
                            caseObjectType: CaseObjectType.inkNote,
                          ),
                        ),
                      ).then((value) {
                        _loadCounts();
                      });
                    }),
                  ],
                ),
              ),

              // Bottom ButtonBar for actions
              OverflowBar(
                alignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    child: const Text('Rename'),
                    onPressed: () => widget.onRename(widget.caseEntity),
                  ),
                  TextButton(
                    child: const Text('Delete'),
                    onPressed: () => widget.onDelete(widget.caseEntity),
                  ),
                  TextButton(
                    child: const Text('Toggle'),
                    onPressed: () => widget.onToggleSelect(widget.caseEntity),
                  ),
                ],
              )
            ])),
          ],
        ),
      ),
    );
  }

  Widget _buildObjectCountIcon(
      IconData icon, String label, int count, onClick) {
    return GestureDetector(
        onTap: onClick ?? () {},
        child: Column(
          children: [
            Icon(icon, size: 24, color: Colors.blueAccent),
            const SizedBox(height: 4),
            Text(
              '$label\n($count)',
              style: const TextStyle(
                  fontSize: 10,
                  color: Colors.black,
                  overflow: TextOverflow.ellipsis),
              textAlign: TextAlign.center,
            ),
          ],
        ));
  }
}
