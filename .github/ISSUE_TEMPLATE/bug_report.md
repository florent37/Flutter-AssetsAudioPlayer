---
name: Bug report
about: Create a report to help us improve
title: ''
labels: bug
assignees: florent37

---

**Flutter Version**

My version : 

**Lib Version**

My version : 

**Platform (Android / iOS / web) + version**

Platform : 

**Describe the bug**

A clear and concise description of what the bug is.

**Small code to reproduce**

```dart
import 'package:assets_audio_player/assets_audio_player.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State {
  
  final AssetsAudioPlayer _assetsAudioPlayer = AssetsAudioPlayer();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: RaisedButton(
            child: Text("open"),
            onPressed: () {
              //open code here
            }
          ),
        ),
      ),
    );
  }
}
```
