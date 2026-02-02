
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IP Monitor',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'IP Monitor'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  final String title;
  const MyHomePage({super.key, required this.title});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String? _ipAddress;
  String? _lastIpAddress;
  Timer? _timer;
  final _portController = TextEditingController();
  final _remoteHostController = TextEditingController();
  final _remotePortController = TextEditingController();
  String _connectionStatus = '';
  ServerSocket? _serverSocket;

  @override
  void initState() {
    super.initState();
    _fetchIpAddress();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _fetchIpAddress());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _serverSocket?.close();
    _portController.dispose();
    _remoteHostController.dispose();
    _remotePortController.dispose();
    super.dispose();
  }

  Future<void> _fetchIpAddress() async {
    try {
      for (var interface in await NetworkInterface.list()) {
        for (var addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            if (_ipAddress != addr.address) {
              setState(() {
                _lastIpAddress = _ipAddress;
                _ipAddress = addr.address;
              });
              if (_lastIpAddress != null && _lastIpAddress != _ipAddress) {
                _showIpChangedNotification();
              }
            }
            return;
          }
        }
      }
      setState(() => _ipAddress = 'Not found');
    } catch (e) {
      setState(() => _ipAddress = 'Error: $e');
    }
  }

  void _showIpChangedNotification() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('IP changed: ${_lastIpAddress ?? ''} -> ${_ipAddress ?? ''}')),
    );
  }

  Future<void> _connectToRemote() async {
    final host = _remoteHostController.text;
    final port = int.tryParse(_remotePortController.text);
    if (host.isEmpty || port == null) {
      setState(() => _connectionStatus = 'Invalid host or port');
      return;
    }
    setState(() => _connectionStatus = 'Connecting...');
    try {
      final socket = await Socket.connect(host, port, timeout: const Duration(seconds: 5));
      setState(() => _connectionStatus = 'Connected to $host:$port');
      socket.destroy();
    } catch (e) {
      setState(() => _connectionStatus = 'Connection failed: $e');
    }
  }

  Future<void> _listenOnPort() async {
    final port = int.tryParse(_portController.text);
    if (port == null) {
      setState(() => _connectionStatus = 'Invalid port');
      return;
    }
    setState(() => _connectionStatus = 'Listening on port $port...');
    try {
      _serverSocket?.close();
      _serverSocket = await ServerSocket.bind(InternetAddress.anyIPv4, port);
      _serverSocket!.listen((client) {
        setState(() => _connectionStatus = 'Received connection from ${client.remoteAddress.address}:${client.remotePort}');
        client.destroy();
      });
    } catch (e) {
      setState(() => _connectionStatus = 'Listen failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            Text('Current IP Address:', style: Theme.of(context).textTheme.titleMedium),
            SelectableText(_ipAddress ?? 'Loading...', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 24),
            Text('Connect to Remote:', style: Theme.of(context).textTheme.titleMedium),
            TextField(
              controller: _remoteHostController,
              decoration: const InputDecoration(labelText: 'Remote Host'),
              keyboardType: TextInputType.text,
            ),
            TextField(
              controller: _remotePortController,
              decoration: const InputDecoration(labelText: 'Remote Port'),
              keyboardType: TextInputType.number,
            ),
            ElevatedButton(
              onPressed: _connectToRemote,
              child: const Text('Connect'),
            ),
            const SizedBox(height: 24),
            Text('Listen on Port:', style: Theme.of(context).textTheme.titleMedium),
            TextField(
              controller: _portController,
              decoration: const InputDecoration(labelText: 'Port'),
              keyboardType: TextInputType.number,
            ),
            ElevatedButton(
              onPressed: _listenOnPort,
              child: const Text('Listen'),
            ),
            const SizedBox(height: 24),
            Text('Status:', style: Theme.of(context).textTheme.titleMedium),
            SelectableText(_connectionStatus),
          ],
        ),
      ),
    );
  }
}
// ...existing code...
