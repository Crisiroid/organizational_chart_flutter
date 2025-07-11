import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:orgchart/main.dart';
import 'package:permission_handler/permission_handler.dart';


class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _requestStoragePermissionsAndNavigate();
  }

  Future<void> _requestStoragePermissionsAndNavigate() async {
    bool permissionsGranted = true;
    if (Platform.isAndroid) {
      if (await Permission.manageExternalStorage.isDenied) {
        final status = await Permission.manageExternalStorage.request();
        if (!status.isGranted) {
          permissionsGranted = false;
        }
      }
      if (await Permission.storage.isDenied) {
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          permissionsGranted = false;
        }
      }
    }
    if (!permissionsGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('اجازه دسترسی به ذخیره‌سازی رد شد')),
      );
    }
    // Navigate after 3 seconds, regardless of permission status
    Timer(Duration(seconds: 3), () {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => TabbedOrgChartScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/logo.jpg',
            ),
            SizedBox(height: 20),
            Text(
              'Org Chart App',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}