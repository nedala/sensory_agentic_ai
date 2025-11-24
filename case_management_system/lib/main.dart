import 'package:case_management_system/screens/objects_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

import 'case_tile.dart';
import 'models/case_model.dart';
import 'utils/db_helper.dart';
import 'utils/file_helper.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CaseManagementApp());
}

class CaseManagementApp extends StatelessWidget {
  const CaseManagementApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final LocalAuthentication auth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    // _authenticate(); // Start authentication on splash screen
  }

  Future<void> _authenticate() async {
    bool isAuthSupported = await auth.isDeviceSupported();
    bool authenticated = false;
    if (isAuthSupported) {
      try {
        authenticated = await auth.authenticate(
          localizedReason: 'Please authenticate to access the app',
          options: const AuthenticationOptions(
            stickyAuth: true,
            biometricOnly: true,
          ),
        );
      } on PlatformException {}

      if (authenticated) {
        _navigateToHome();
      } else {
        // Handle authentication failure
        _showAuthFailedDialog();
      }
    } else {
      _navigateToHome();
    }
  }

  void _navigateToHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const CaseListScreen()),
    );
  }

  void _showAuthFailedDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Authentication Failed'),
        content: const Text('Unable to authenticate. The app will close now.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              SystemNavigator.pop(); // Close the app
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.white,
        body: Expanded(
          child: GestureDetector(
            onTap: _navigateToHome,
            child: Container(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('images/covers/fabric_texture.jpeg'),
                  fit: BoxFit.cover,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Center(
                      child: Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(color: Colors.white, width: 8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.5),
                          spreadRadius: 4,
                          blurRadius: 8,
                          offset:
                              const Offset(0, 8), // changes position of shadow
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'images/ustda.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  )),
                  const SizedBox(height: 40),
                  const Text(
                    'USTDA Case Manager',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Touch to Open',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ));
  }
}

class CaseListScreen extends StatefulWidget {
  const CaseListScreen({super.key});

  @override
  _CaseListScreenState createState() => _CaseListScreenState();
}

class _CaseListScreenState extends State<CaseListScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final FileHelper _fileHelper = FileHelper();
  final Uuid uuid = const Uuid();
  List<Case> cases = [];
  List<Case> selectedCases = [];
  bool isSelectionMode = false;
  Contact myContact = Contact(id: '', displayName: '');

  @override
  void initState() {
    super.initState();
    _loadCases();
    _loadMyContact();
  }

  Future<void> _loadCases() async {
    final loadedCases = await _dbHelper.getCases();
    setState(() {
      cases = loadedCases;
      selectedCases.clear();
      isSelectionMode = selectedCases.isNotEmpty;
    });
  }

  // Toggle selection mode
  void _toggleSelectionMode(Case caseEntity) {
    setState(() {
      if (selectedCases.contains(caseEntity)) {
        selectedCases.remove(caseEntity);
      } else {
        selectedCases.add(caseEntity);
      }
      isSelectionMode = selectedCases.isNotEmpty;
    });
  }

  // Confirm deletion
  Future<void> _confirmDeleteCases() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Selected Cases'),
          content: Text(
              'Are you sure you want to delete ${selectedCases.length} cases?'),
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
      await _deleteSelectedCases();
    }
  }

  // Delete selected cases
  Future<void> _deleteSelectedCases() async {
    if (selectedCases.isNotEmpty) {
      for (Case caseEntity in selectedCases) {
        await _dbHelper.deleteCase(caseEntity.id);
      }
      setState(() {
        cases.removeWhere((c) => selectedCases.contains(c));
      });
      _loadCases(); // Reload the cases
    }
  }

  // Rename case
  Future<void> _renameCaseDialog(Case caseEntity) async {
    String? newTitle = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        TextEditingController caseTitleController =
            TextEditingController(text: caseEntity.title);
        return AlertDialog(
          title: const Text('Rename Case'),
          content: TextField(
            controller: caseTitleController,
            decoration: const InputDecoration(hintText: 'Enter new case title'),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.pop(context),
            ),
            TextButton(
              child: const Text('Rename'),
              onPressed: () => Navigator.pop(context, caseTitleController.text),
            ),
          ],
        );
      },
    );
    if (newTitle!.isNotEmpty) {
      setState(() {
        caseEntity.title = newTitle;
      });
      await _dbHelper.updateCase(caseEntity);
      _loadCases(); // Reload the cases
    }
  }

  Future<void> _loadMyContact() async {
    if (await FlutterContacts.requestPermission(readonly: true)) {
      final allContacts =
          await FlutterContacts.getContacts(withProperties: true);
      String currentId = await _fileHelper.loadSelfContactID();
      Contact contact = Contact(id: '', displayName: '');
      try {
        contact = allContacts.firstWhere((contact) => contact.id == currentId);
      } catch (e) {
        contact = Contact(
            id: '',
            displayName: ''); // Set contact to null if no match is found
      }
      setState(() {
        myContact = contact;
      });
    }
  }

  void _shareMyContact() {
    if (myContact.id != '' && myContact.displayName.isNotEmpty) {
      Share.share(
        'Contact Info:\nName: ${myContact.displayName}\nPhone: ${myContact.phones.isNotEmpty ? myContact.phones.first.number : 'N/A'}\nPhone 2: ${myContact.phones.isNotEmpty && myContact.phones.length > 1 ? myContact.phones[1].number : 'N/A'}\nEmail: ${myContact.emails.isNotEmpty ? myContact.emails.first.address : 'N/A'}',
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No valid contact information to share.')),
      );
    }
  }

  Future<void> _resetMyContact() async {
    _fileHelper.saveSelfContactID('');
    setState(() {
      myContact = Contact(id: '', displayName: '');
    });
  }

  Future<void> _selectMyContact() async {
    if (await FlutterContacts.requestPermission()) {
      Contact? selectedContact = await FlutterContacts.openExternalPick();
      if (selectedContact != null) {
        setState(() {
          myContact = selectedContact;
          if (myContact.id.isNotEmpty) {
            _fileHelper.saveSelfContactID(myContact.id);
            _loadMyContact();
          }
        });
      }
    }
  }

  // Insert a new case into the database
  Future<void> _saveCase(Case caseEntity) async {
    await _dbHelper.insertCase(caseEntity);
    await _loadCases(); // Reload cases after saving
  }

  Future<void> _addNewCaseDialog(BuildContext context) async {
    String? caseTitle = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        TextEditingController caseTitleController = TextEditingController();
        return AlertDialog(
          title: const Text('New Case Title'),
          content: TextField(
            controller: caseTitleController,
            decoration: const InputDecoration(hintText: 'Enter case title'),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.pop(context),
            ),
            TextButton(
              child: const Text('OK'),
              onPressed: () => Navigator.pop(context, caseTitleController.text),
            ),
          ],
        );
      },
    );

    if (caseTitle!.isNotEmpty) {
      final newCase = Case(
        id: uuid.v4(), // Generate a unique ID using UUID
        title: caseTitle,
        createdAt: DateTime.now(),
        caseObjects: [],
      );
      await _saveCase(newCase).then((value) {
        _loadCases();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    isSelectionMode = selectedCases.isNotEmpty;
    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        title: isSelectionMode
            ? Text('${selectedCases.length} selected')
            : const Text('Case Management System'),
        actions: isSelectionMode
            ? [
                selectedCases.length == 1
                    ? IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _renameCaseDialog(selectedCases.first),
                      )
                    : const SizedBox.shrink(),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: _confirmDeleteCases,
                ),
                IconButton(
                  icon: const Icon(Icons.share),
                  onPressed: () => {}, // To do later
                ),
              ]
            : [
                IconButton(
                  icon: const Icon(Icons.create_new_folder),
                  onPressed: () => _addNewCaseDialog(context),
                  tooltip: 'Add New Case',
                ),
              ],
        leading: isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    isSelectionMode = false;
                    selectedCases.clear();
                  });
                },
              )
            : null,
      ),
      body: Container(
          decoration: const BoxDecoration(
              // Add a background image
              image: DecorationImage(
            image: AssetImage('images/covers/light_texture.jpg'),
            opacity: 0.2,
            fit: BoxFit.cover,
          )),
          child: cases.isEmpty
              ? _buildEmptyState()
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: _buildCaseList(),
                )),
      // Multiple Floating Action Buttons
      floatingActionButton: !isSelectionMode
          ? Align(
              alignment:
                  Alignment.bottomRight, // Align the FABs to the bottom right
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  FloatingActionButton.extended(
                    onPressed:
                        myContact.id != '' ? _resetMyContact : _selectMyContact,
                    label: Text(
                        '${myContact.id != '' ? 'Reset' : 'Set'} My Contact'),
                    icon: const Icon(Icons.contact_emergency),
                    tooltip:
                        'My Contact Info ${myContact.id != '' ? myContact.displayName : ''}',
                  ),
                  const SizedBox(height: 10),
                  (myContact.id != '')
                      ? FloatingActionButton.extended(
                          onPressed: _shareMyContact,
                          label: const Text('Share My Contact Info'),
                          icon: const Icon(Icons.contactless),
                          tooltip: 'Share My Contact Info',
                        )
                      : const SizedBox.shrink(),
                ],
              ),
            )
          : null,
    );
  }

  // Build empty state with tooltip message
  Widget _buildEmptyState() {
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
            onTap: () => _addNewCaseDialog(
                context), // Encourage user to create a new case
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
                  const Text(
                    'No Cases Yet',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Tap here to create your first case and get started.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCaseList() {
    return ListView.builder(
      itemCount: cases.length,
      itemExtent: 334,
      itemBuilder: (context, index) {
        final caseEntity = cases[index];
        return CaseTile(
          caseEntity: caseEntity,
          isSelected: selectedCases.contains(caseEntity),
          onRename: (caseEntity) => _renameCaseDialog(caseEntity),
          onDelete: (caseEntity) => _confirmDeleteCase(caseEntity),
          onShare: (caseEntity) => (), // To do later
          onToggleSelect: (caseEntity) => _toggleSelectionMode(caseEntity),
          dbHelper: _dbHelper,
          fileHelper: _fileHelper,
        );
      },
    );
  }

  // Confirm deletion
  Future<void> _confirmDeleteCase(Case caseEntity) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Case'),
          content: Text(
              'Are you sure you want to delete the case "${caseEntity.title}"?'),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.pop(
                    context, false); // Return false when cancel is pressed
              },
            ),
            TextButton(
              child: const Text('Delete'),
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
      await _dbHelper.deleteCase(caseEntity.id);
      setState(() {
        cases.removeWhere((c) => c.id == caseEntity.id);
        selectedCases.remove(caseEntity);
        isSelectionMode = selectedCases.isNotEmpty;
      });
    }
  }
}
