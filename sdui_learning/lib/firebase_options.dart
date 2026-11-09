// Generated from FlutterFire config for project sdui-learning.
// Ignore: avoid_classes_with_only_static_members

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static bool get isConfigured => true;

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      default:
        return android;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAwe0LqpJnBLDHIKl6tnH7XmC4EPebGwrk',
    appId: '1:296137172782:android:b544e46393df39f04dfcbf',
    messagingSenderId: '296137172782',
    projectId: 'sdui-learning',
    authDomain: 'sdui-learning.firebaseapp.com',
    storageBucket: 'sdui-learning.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAwe0LqpJnBLDHIKl6tnH7XmC4EPebGwrk',
    appId: '1:296137172782:android:b544e46393df39f04dfcbf',
    messagingSenderId: '296137172782',
    projectId: 'sdui-learning',
    storageBucket: 'sdui-learning.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAGx94HsiZ35i9XNoVQJObSiP5zylpB62I',
    appId: '1:296137172782:ios:658ac3290383e0c04dfcbf',
    messagingSenderId: '296137172782',
    projectId: 'sdui-learning',
    storageBucket: 'sdui-learning.firebasestorage.app',
    iosBundleId: 'com.example.sduiLearning',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyAGx94HsiZ35i9XNoVQJObSiP5zylpB62I',
    appId: '1:296137172782:ios:658ac3290383e0c04dfcbf',
    messagingSenderId: '296137172782',
    projectId: 'sdui-learning',
    storageBucket: 'sdui-learning.firebasestorage.app',
    iosBundleId: 'com.example.sduiLearning',
  );
}
