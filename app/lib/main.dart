import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() => runApp(const SauiApp());

class SauiApp extends StatelessWidget {
  const SauiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SAUI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF9B8CFF),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF101018),
        useMaterial3: true,
      ),
      home: const ConverterPage(),
    );
  }
}

class PickedAudio {
  final String name;
  final Uint8List bytes;
  PickedAudio(this.name, this.bytes);
}

class ConverterPage extends StatefulWidget {
  const ConverterPage({super.key});

  @override
  State<ConverterPage> createState() => _ConverterPageState();
}

class _ConverterPageState extends State<ConverterPage> {
  static const backendUrl = String.fromEnvironment(
    'SAUI_API_URL',
    defaultValue: 'http://localhost:8000',
  );

  PickedAudio? song;
  PickedAudio? voice;
  bool busy = false;
  String status = 'Add a song and a voice reference to get started.';
  double pitch = 0;
  double strength = 0.7;

  Future<void> pickAudio(bool isVoice) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['wav', 'mp3', 'm4a', 'flac', 'ogg'],
      withData: true,
    );
    if (result == null || result.files.single.bytes == null) return;
    final file = result.files.single;
    setState(() {
      final picked = PickedAudio(file.name, file.bytes!);
      if (isVoice) {
        voice = picked;
      } else {
        song = picked;
      }
      status = 'Files ready. Adjust settings, then tap Convert.';
    });
  }

  Future<void> convert() async {
    if (song == null || voice == null || busy) return;
    setState(() {
      busy = true;
      status = 'Sending audio to the SAUI conversion server…';
    });
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$backendUrl/convert'),
      )
        ..fields['pitch_shift'] = pitch.round().toString()
        ..fields['strength'] = strength.toString()
        ..files.add(http.MultipartFile.fromBytes(
          'song',
          song!.bytes,
          filename: song!.name,
        ))
        ..files.add(http.MultipartFile.fromBytes(
          'voice_reference',
          voice!.bytes,
          filename: voice!.name,
        ));

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      final contentType = response.headers['content-type'] ?? '';

      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          contentType.contains('audio/wav')) {
        await FileSaver.instance.saveFile(
          name: 'saui_converted',
          bytes: response.bodyBytes,
          fileExtension: 'wav',
          mimeType: MimeType.wav,
        );
        setState(() => status = 'Conversion finished. Your WAV file was saved.');
      } else {
        String message = 'Conversion service returned ${response.statusCode}.';
        try {
          final body = jsonDecode(response.body);
          message = body['detail']?.toString() ?? message;
        } catch (_) {
          // Keep the HTTP status message when the server response is not JSON.
        }
        setState(() => status = message);
      }
    } catch (e) {
      setState(() => status =
          'Could not complete the request. Check that the SAUI server is running and reachable.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget uploadTile({
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
    required IconData icon,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF1B1B29),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? const Color(0xFF9B8CFF) : Colors.white12,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFFB8ADFF), size: 30),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(selected ? subtitle : 'Tap to choose an audio file',
                      style: const TextStyle(color: Colors.white60)),
                ],
              ),
            ),
            const Icon(Icons.upload_file, color: Colors.white54),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ready = song != null && voice != null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('SAUI', style: TextStyle(fontWeight: FontWeight.w800)),
        centerTitle: false,
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 18),
            child: Center(child: Text('VOICE STUDIO',
                style: TextStyle(letterSpacing: 2, color: Colors.white54))),
          )
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(22),
            children: [
              const SizedBox(height: 18),
              const Text('Transform your vocals.',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              const Text('Upload a song and a voice reference. Keep the melody and timing.',
                  style: TextStyle(color: Colors.white60, fontSize: 15)),
              const SizedBox(height: 28),
              uploadTile(
                title: 'Song audio',
                subtitle: song?.name ?? '',
                selected: song != null,
                onTap: () => pickAudio(false),
                icon: Icons.music_note,
              ),
              const SizedBox(height: 12),
              uploadTile(
                title: 'Voice reference',
                subtitle: voice?.name ?? '',
                selected: voice != null,
                onTap: () => pickAudio(true),
                icon: Icons.record_voice_over,
              ),
              const SizedBox(height: 26),
              const Text('PITCH SHIFT', style: TextStyle(letterSpacing: 1.4, fontWeight: FontWeight.bold)),
              Row(
                children: [
                  const Text('-12'),
                  Expanded(
                    child: Slider(
                      value: pitch,
                      min: -12,
                      max: 12,
                      divisions: 24,
                      label: pitch.round().toString(),
                      onChanged: (v) => setState(() => pitch = v),
                    ),
                  ),
                  const Text('+12'),
                ],
              ),
              Text('Pitch: ${pitch.round()} semitones',
                  style: const TextStyle(color: Colors.white60)),
              const SizedBox(height: 18),
              const Text('VOICE STRENGTH', style: TextStyle(letterSpacing: 1.4, fontWeight: FontWeight.bold)),
              Slider(
                value: strength,
                min: 0,
                max: 1,
                divisions: 20,
                label: strength.toStringAsFixed(2),
                onChanged: (v) => setState(() => strength = v),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: ready && !busy ? convert : null,
                icon: busy
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.auto_awesome),
                label: Text(busy ? 'CONVERTING…' : 'CONVERT VOICE'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                  backgroundColor: const Color(0xFF7865E8),
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B1B29),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(status, style: const TextStyle(color: Colors.white70)),
              ),
              const SizedBox(height: 24),
              const Text('Output: WAV • 44.1 kHz singing-voice model',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white38, fontSize: 12)),
              const SizedBox(height: 20),
              const Text(
                'Use only voice recordings you have permission to use. Audio is sent to the backend you configure.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
