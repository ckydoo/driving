import 'dart:convert';
import 'package:flutter/material.dart';

class CsvDiagnosticDialog extends StatelessWidget {
  final List<int> fileBytes;
  final String fileName;

  const CsvDiagnosticDialog({
    Key? key,
    required this.fileBytes,
    required this.fileName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 600,
        height: 500,
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'CSV File Diagnostic: $fileName',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: _buildDiagnosticInfo(),
              ),
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Close'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiagnosticInfo() {
    try {
      // Basic file info
      String fileInfo = _getFileInfo();

      // Try to decode as different encodings
      Map<String, String> encodingTests = _testEncodings();

      // Analyze raw content
      String rawAnalysis = _analyzeRawContent();

      // Try different delimiters
      Map<String, String> delimiterTests = _testDelimiters();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSection('File Information', fileInfo),
          _buildSection(
              'Encoding Tests',
              encodingTests.entries
                  .map((e) => '${e.key}: ${e.value}')
                  .join('\n')),
          _buildSection('Content Analysis', rawAnalysis),
          _buildSection(
              'Delimiter Tests',
              delimiterTests.entries
                  .map((e) => '${e.key}: ${e.value}')
                  .join('\n')),
        ],
      );
    } catch (e) {
      return Text('Error analyzing file: ${e.toString()}');
    }
  }

  Widget _buildSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            content,
            style: TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
        SizedBox(height: 16),
      ],
    );
  }

  String _getFileInfo() {
    return '''
File Size: ${fileBytes.length} bytes
First 20 bytes (hex): ${fileBytes.take(20).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}
First 20 bytes (dec): ${fileBytes.take(20).join(', ')}
BOM Detection: ${_detectBOM()}
''';
  }

  String _detectBOM() {
    if (fileBytes.length >= 3) {
      if (fileBytes[0] == 0xEF &&
          fileBytes[1] == 0xBB &&
          fileBytes[2] == 0xBF) {
        return 'UTF-8 BOM detected';
      }
    }
    if (fileBytes.length >= 2) {
      if (fileBytes[0] == 0xFF && fileBytes[1] == 0xFE) {
        return 'UTF-16 LE BOM detected';
      }
      if (fileBytes[0] == 0xFE && fileBytes[1] == 0xFF) {
        return 'UTF-16 BE BOM detected';
      }
    }
    return 'No BOM detected';
  }

  Map<String, String> _testEncodings() {
    Map<String, String> results = {};

    try {
      String utf8Result = utf8.decode(fileBytes);
      results['UTF-8'] = 'Success - ${utf8Result.length} characters';
    } catch (e) {
      results['UTF-8'] = 'Failed: ${e.toString()}';
    }

    try {
      String latin1Result = latin1.decode(fileBytes);
      results['Latin-1'] = 'Success - ${latin1Result.length} characters';
    } catch (e) {
      results['Latin-1'] = 'Failed: ${e.toString()}';
    }

    try {
      String asciiResult = ascii.decode(fileBytes);
      results['ASCII'] = 'Success - ${asciiResult.length} characters';
    } catch (e) {
      results['ASCII'] = 'Failed: ${e.toString()}';
    }

    return results;
  }

  String _analyzeRawContent() {
    try {
      String content = utf8.decode(fileBytes, allowMalformed: true);
      List<String> lines = content.split('\n');

      Map<String, int> charFrequency = {};
      for (int char in content.codeUnits) {
        String charStr = String.fromCharCode(char);
        charFrequency[charStr] = (charFrequency[charStr] ?? 0) + 1;
      }

      // Sort by frequency
      List<MapEntry<String, int>> sortedChars = charFrequency.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      String frequentChars = sortedChars.take(10).map((e) {
        String char = e.key;
        if (char == '\n') char = '\\n';
        if (char == '\r') char = '\\r';
        if (char == '\t') char = '\\t';
        if (char == ' ') char = 'SPACE';
        return '$char: ${e.value}';
      }).join(', ');

      return '''
Total lines: ${lines.length}
First line length: ${lines.isNotEmpty ? lines.first.length : 0}
Line ending type: ${_detectLineEndings(content)}
Most frequent chars: $frequentChars
First line preview: ${lines.isNotEmpty ? lines.first.substring(0, lines.first.length > 100 ? 100 : lines.first.length) : 'Empty'}
''';
    } catch (e) {
      return 'Analysis failed: ${e.toString()}';
    }
  }

  String _detectLineEndings(String content) {
    int rnCount = '\r\n'.allMatches(content).length;
    int nCount = '\n'.allMatches(content).length - rnCount;
    int rCount = '\r'.allMatches(content).length - rnCount;

    if (rnCount > 0) return 'Windows (\\r\\n)';
    if (nCount > 0) return 'Unix (\\n)';
    if (rCount > 0) return 'Mac Classic (\\r)';
    return 'None detected';
  }

  Map<String, String> _testDelimiters() {
    Map<String, String> results = {};
    List<String> delimiters = [',', ';', '\t', '|', ':'];

    try {
      String content = utf8.decode(fileBytes, allowMalformed: true);
      List<String> lines = content.split('\n');
      String firstLine = lines.isNotEmpty ? lines.first : '';

      for (String delimiter in delimiters) {
        int count = delimiter.allMatches(firstLine).length;
        String delimiterName = delimiter;
        if (delimiter == '\t') delimiterName = 'TAB';
        if (delimiter == ' ') delimiterName = 'SPACE';

        results[delimiterName] = '$count occurrences in first line';
      }
    } catch (e) {
      results['Error'] = e.toString();
    }

    return results;
  }
}

// Helper function to show diagnostic dialog
void showCsvDiagnostic(
    BuildContext context, List<int> fileBytes, String fileName) {
  showDialog(
    context: context,
    builder: (context) => CsvDiagnosticDialog(
      fileBytes: fileBytes,
      fileName: fileName,
    ),
  );
}
