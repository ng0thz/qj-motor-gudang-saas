import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

// Satu halaman scan dipakai Online + Offline
// Return barcode string via Navigator.pop(context, code)
class ScanPage extends StatefulWidget {
  final String title;
  const ScanPage({super.key, this.title = 'QJ Motor - Scan'});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  bool _handled = false;
  final _controller = MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title), backgroundColor: const Color(0xFF1B2A4A), foregroundColor: Colors.white),
      body: Column(children: [
        Expanded(
          child: MobileScanner(
            controller: _controller,
            onDetect: (cap) {
              if (_handled) return;
              final code = cap.barcodes.first.rawValue;
              if (code == null || code.isEmpty) return;
              _handled = true;
              Navigator.pop(context, code);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            decoration: const InputDecoration(hintText: 'Atau ketik manual: 05523M79K500', prefixIcon: Icon(Icons.keyboard), border: OutlineInputBorder()),
            textInputAction: TextInputAction.done,
            onSubmitted: (v) {
              if (v.trim().isEmpty) return;
              Navigator.pop(context, v.trim());
            },
          ),
        ),
      ]),
    );
  }
}

// Helper: buka scan lalu kembalikan code
Future<String?> openScan(BuildContext context, {String title = 'QJ Motor - Scan'}) {
  return Navigator.push<String?>(context, MaterialPageRoute(builder: (_) => ScanPage(title: title)));
}
