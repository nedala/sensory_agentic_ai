# Case Management System

A Flutter-based case management application that allows users to manage cases with features such as inking notes, voice memos, pictures, and text notes. The app also includes functionality for sharing contacts and exporting cases. 

## Features

- **Case Management:** Create, edit, and delete cases.
- **Inking Notes:** Capture handwritten notes on an ink canvas with dynamic text recognition using Google ML Kit.
- **Voice Memos:** Record and store voice memos associated with a case.
- **Pictures:** Add, view, and delete photos associated with a case.
- **Text Notes:** Add and manage text-based notes for each case.
- **Share My Contact:** Share your own contact details.
- **Export Case:** Export case data for sharing or backup.

## Screenshots

### Main Screen - Case Manager
![Main Screen](./screenshots/main_screen_case_manager.png)

### Inking Notes - Digitized Live
![Notes Digitized](./screenshots/notes_digitized_live.png)

### Add and Edit Notes
![Add/Edit Notes](./screenshots/notes_add_edit.png)

### Images, Videos, and Memos Management
![Media Management](./screenshots/images_videos_memos_add_edit.png)

### Manage Contacts and Documents
![Contacts & Documents](./screenshots/manage_contacts_documents.png)

### Case Objects
![Case Objects](./screenshots/case_objects.png)

### Inking Notes - Write & Recognize
![Inking Notes](./screenshots/can_ink_notes_too.png)


## Getting Started

### Prerequisites

Before you begin, ensure you have the following installed:

- [Flutter SDK](https://flutter.dev/docs/get-started/install) (>= 3.x)
- Android Studio or Xcode for iOS (to run the app on an emulator or device)
- [Google ML Kit](https://developers.google.com/ml-kit) for Digital Ink Recognition

### Installation

1. **Clone the repository**

   ```bash
   git clone git@github.com:nedala/case_manager.git
   cd case_manager
   ```

2. **Install dependencies**

   ```bash
   flutter pub get
   ```

3. **Run the app**

   To run the app on an emulator or connected device:

   ```bash
   flutter run
   ```

### Digital Ink Recognition Setup

To enable inking note recognition, you need to include Google ML Kit in your app. The app already integrates the Digital Ink Recognition API.

- Download the necessary recognition model dynamically within the app, or pre-package the model for offline use.
- The following language models are available: `en` (English), `es` (Spanish), `fr` (French), etc.

### Export Cases

You can export case data, including inking notes, voice memos, and pictures, by selecting the "Export Case" option. This will generate a JSON file that you can share or backup.

## Folder Structure

```plaintext
.
├── lib
│   ├── models
│   │   └── case_model.dart        # Model for case entity
│   ├── screens
│   │   ├── case_list_screen.dart  # Main screen with case list
│   │   ├── ink_notes_screen.dart  # Screen for managing inking notes
│   │   ├── voice_memos_screen.dart # Screen for managing voice memos
│   └── utils
│       ├── db_helper.dart         # SQLite database helper
│       └── file_helper.dart       # Helper functions for file operations
├── assets
│   └── images
├── screenshots                    # Add screenshots for the README
└── pubspec.yaml                   # Flutter project configuration
```

## How It Works

### Inking Notes with Recognition

The inking notes feature allows users to draw on a canvas, and the app uses Google ML Kit’s Digital Ink Recognition to recognize text from the drawing. If text is recognized, it is dynamically labeled. If no text is recognized, the note defaults to "Inking Note #".

### Sharing Contact

The "Share My Contact" feature allows you to pull your own contact information (phone number, email, etc.) and share it using native sharing options.

### Exporting a Case

The "Export Case" feature generates a JSON file that includes all associated data for a case (e.g., inking notes, pictures, voice memos) that you can share or back up.
