import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AppConfig {
  static const String apiKey = 'YOUR_API_KEY';
  static const String apiSecret = 'YOUR_API_SECRET';
}

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SMS Verify',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue)
      ),
      debugShowCheckedModeBanner: false,
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  MyHomePageState createState() => MyHomePageState();
}

class MyHomePageState extends State<MyHomePage> {
  final _phoneNumberController = TextEditingController();
  bool _isLoading = false;
  String? _requestId;

  @override
  void dispose() {
    _phoneNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SMS Verify'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          //mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(20), // アイコン周りのパディング
              decoration: const BoxDecoration(
                color: Colors.black26, // 円の色
                shape: BoxShape.circle, // 円形
              ),
              child: const Icon(Icons.phone_android, size: 80, color: Colors.white), // アイコンの色とサイズ
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _phoneNumberController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Enter your phone number',
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  await attemptSendVerification();
                  if (!mounted) return; // 非同期操作の後、ウィジェットがまだビルドツリーに存在しているか確認
                  if (_requestId != null) {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => VerifyCodePage(requestId: _requestId!)),
                    );
                  } else {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(const SnackBar(content: Text("Verification request failed")));
                  }
                },
                child: const Text('Send'),
              ),
            ),
            const SizedBox(height: 20),
            _isLoading ? const CircularProgressIndicator() : const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }

  Future<void> attemptSendVerification() async {
    String phoneNumber = _phoneNumberController.text;

    setState(() {
      _isLoading = true;
    });

    var result = await sendVerificationRequest(AppConfig.apiKey, AppConfig.apiSecret, phoneNumber);

    setState(() {
      _isLoading = false;
      if (result != null) {
        _requestId = result;
      }
    });
  }

  Future<String?> sendVerificationRequest(String apiKey, String apiSecret, String phoneNumber) async {
    var url = Uri.parse('https://api.nexmo.com/verify/json'
        '?api_key=$apiKey'
        '&api_secret=$apiSecret'
        '&number=$phoneNumber'
        '&brand=MyAppName'
        '&sender_id=MyCompany'
        '&code_length=4'
        '&workflow_id=6' // SMS only
        );

    try {
      var response = await http.get(url);
      if (response.statusCode == 200) {
        var data = json.decode(response.body);
        if (kDebugMode) {
          print('verify response: $data');
        }
        if (data['status'] == '0') {
          return data['request_id'];
        }
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error: $e');
      }
      return null;
    }
  }
}

class VerifyCodePage extends StatefulWidget {
  final String requestId;
  const VerifyCodePage({Key? key, required this.requestId}) : super(key: key);

  @override
  VerifyCodePageState createState() => VerifyCodePageState();
}

class VerifyCodePageState extends State<VerifyCodePage> {
  final _codeController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Enter Verification Code'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(20), // アイコン周りのパディング
                decoration: const BoxDecoration(
                  color: Colors.black26, // 円の色
                  shape: BoxShape.circle, // 円形
                ),
                child: const Icon(Icons.key, size: 80, color: Colors.white), // アイコンの色とサイズ
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: 170,
                child: TextField(
                  controller: _codeController,
                  maxLength: 4,
                  decoration: const InputDecoration(
                    labelText: '',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    String code = _codeController.text;
                    setState(() {
                      _isLoading = true;
                    });
                    bool isVerified = await verifyCode(AppConfig.apiKey, AppConfig.apiSecret, widget.requestId, code);
                    setState(() {
                      _isLoading = false;
                    });
                    if (!mounted) return;
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (context) => AuthResultPage(isSuccess: isVerified),
                      ),
                    );
                  },
                  child: const Text('Verify'),
                ),
              ),
              const SizedBox(height: 20),
              _isLoading ? const CircularProgressIndicator() : const SizedBox.shrink(),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> verifyCode(String apiKey, String apiSecret, String requestId, String code) async {
    var url = Uri.parse('https://api.nexmo.com/verify/check/json'
        '?api_key=$apiKey'
        '&api_secret=$apiSecret'
        '&request_id=$requestId'
        '&code=$code');

    try {
      var response = await http.get(url);
      if (response.statusCode == 200) {
        var data = json.decode(response.body);
        if (kDebugMode) {
          print('check response: $data');
        }
        return data['status'] == '0'; // 成功した場合trueを返す
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('Error: $e');
      }
      return false;
    }
  }
}

class AuthResultPage extends StatelessWidget {
  final bool isSuccess;
  const AuthResultPage({Key? key, required this.isSuccess}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Authentication Result'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(children: <Widget>[
            Container(
              padding: const EdgeInsets.all(20), // アイコン周りのパディング
              decoration: BoxDecoration(
                color: isSuccess ? Colors.green : Colors.amber, // 円の色
                shape: BoxShape.circle, // 円形
              ),
              child: Icon(isSuccess ? Icons.check : Icons.warning_amber, size: 80, color: Colors.white), // アイコンの色とサイズ
            ),
            const SizedBox(height: 20),
            Text(
              isSuccess ? 'Authentication Successful!' : 'Authentication Failed.',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ]),
        ),
      ),
    );
  }
}
