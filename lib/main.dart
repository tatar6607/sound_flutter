import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart';

import 'package:sound_stream/sound_stream.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final RecorderStream _recorder = RecorderStream();
  final PlayerStream _player = PlayerStream();
  late IO.Socket socket;
  String socketAddress = "https://sound-ozkan.herokuapp.com/";

  final List<Uint8List> _micChunks = [];
  bool _isRecording = false;
  bool _isPlaying = false;

  StreamSubscription? _recorderStatus;
  StreamSubscription? _playerStatus;
  StreamSubscription? _audioStream;

  @override
  void initState() {
    super.initState();

    socket = IO.io(
        socketAddress,
        OptionBuilder()
            .setTransports(['websocket']) // for Flutter or Dart VM
            .disableAutoConnect() // disable auto-connection
            .build());
    socket.connect();

    initPlugin();
  }

  @override
  void dispose() {
    _recorderStatus?.cancel();
    _playerStatus?.cancel();
    _audioStream?.cancel();
    super.dispose();
  }

  Future<void> initPlugin() async {
    _recorderStatus = _recorder.status.listen((status) {
      if (mounted) {
        setState(() {
          _isRecording = status == SoundStreamStatus.Playing;
        });
      }
    });

    _audioStream = _recorder.audioStream.listen((data) {
      if (_isPlaying) {
        _player.writeChunk(data);
      } else {
        _micChunks.add(data);
      }
    });

    _playerStatus = _player.status.listen((status) {
      if (mounted) {
        setState(() {
          _isPlaying = status == SoundStreamStatus.Playing;
        });
      }
    });

    await Future.wait([
      _recorder.initialize(),
      _player.initialize(),
    ]);
  }

  void _play() async {
    await _player.start();

    if (_micChunks.isNotEmpty) {
      for (var chunk in _micChunks) {
        await _player.writeChunk(chunk);
      }
      _micChunks.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
                iconSize: 96.0,
                icon: Icon(_isRecording ? Icons.mic_off : Icons.mic),
                onPressed: () {
                  if (_isRecording) {
                    _recorder.stop();
                  } else {
                    _recorder.start();
                  }
                }),
            IconButton(
              iconSize: 96.0,
              icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
              onPressed: _isPlaying ? _player.stop : _play,
            ),
          ],
        ),
      ),
    );
  }
}
