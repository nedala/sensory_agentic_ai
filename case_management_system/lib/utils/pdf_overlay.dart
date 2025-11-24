import 'dart:ui';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:pdf/widgets.dart' as pw;
import 'package:path/path.dart' as path;
import 'dart:io';
import 'file_helper.dart';

class TextBlockData {
  final String text;
  final Rect boundingBox;
  TextBlockData({required this.text, required this.boundingBox});
}

Rect _scaleRect(
  Rect rect,
  Size imageSize,
  PdfPageFormat pageFormat, {
  double margin = 0,
}) {
  final scaleX = (pageFormat.width - 2 * margin) / imageSize.width;
  final scaleY = (pageFormat.height - 2 * margin) / imageSize.height;

  final left = rect.left * scaleX + margin;
  final top = rect.top * scaleY + margin;
  final width = rect.width * scaleX;
  final height = rect.height * scaleY;

  return Rect.fromLTWH(left, top, width, height);
}

Future<String> createTextOverlaidPDF(String filePath, String fileName) async {
  // Initialize the text recognizer
  final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  final FileHelper fileHelper = FileHelper();

  // Create a new PDF document using `pdf` package
  final pdf = pw.Document();

  // Open the scanned PDF file using `pdfx`
  final pdfx.PdfDocument originalPdf = await pdfx.PdfDocument.openFile(filePath);

  // Loop through each page and perform OCR
  for (var i = 0; i < originalPdf.pagesCount; i++) {
    final pdfx.PdfPage page = await originalPdf.getPage(i + 1);

    // Convert each page to an image (required for OCR)
    final img = await page.render(
      width: page.width * 2,
      height: page.height * 2,
      format: pdfx.PdfPageImageFormat.png,
    );

    if (img == null) continue;

    // Get temporary directory to save the image file temporarily
    final tempDir = await getTemporaryDirectory();
    final imageFile = File('${tempDir.path}/page_$i.png');
    await imageFile.writeAsBytes(img.bytes);

    // Perform OCR on the image
    final inputImage = InputImage.fromFilePath(imageFile.path);
    final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);

    final List<TextBlockData> textBlocks = recognizedText.blocks.map((block) {
      return TextBlockData(
        text: block.text,
        boundingBox: block.boundingBox,
      );
    }).toList();

    // Delete the temporary image file after OCR processing
    await imageFile.delete();

    // Use the `decodedImage` dimensions to scale text correctly
    final imageSize = Size(page.width * 2, page.height * 2);

    // Create a new page format for the new PDF
    final pageFormat = PdfPageFormat(
      page.width.toDouble(),
      page.height.toDouble(),
      marginAll: 0,
    );

    // Add the original image to the new PDF using `pdf` (`pw`)
    final pdfImage = pw.MemoryImage(img.bytes);

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        build: (pw.Context context) {
          return pw.Stack(
            children: [
              pw.Image(pdfImage), // Display the rendered image

              // Overlay each recognized text block
              ...textBlocks.map((block) {
                final rect = _scaleRect(
                  block.boundingBox,
                  imageSize,
                  pageFormat,
                );
                return pw.Positioned(
                  left: rect.left,
                  top: rect.top,
                  child: pw.Container(
                    color: const PdfColor.fromInt(0x99000000), // Semi-transparent background for text
                    padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: pw.Text(
                      block.text,
                      style: const pw.TextStyle(
                        fontSize: 12,
                        color: PdfColors.white,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ],
          );
        },
      ),
    );

    // Close each page after processing
    await page.close();
  }

  // Save the new PDF with overlaid text
  final newFilePath = await fileHelper.saveBinaryDataFromUint8List(
    path.basename(fileName),
    await pdf.save(),
  );

  // Clean up resources
  textRecognizer.close();
  originalPdf.close();

  return newFilePath;
}
