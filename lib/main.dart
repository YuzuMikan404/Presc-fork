import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:presc/features/playback/ui/providers/playback_provider.dart';
import 'package:presc/features/playback/ui/providers/playback_timer_provider.dart';
import 'package:presc/features/playback/ui/providers/playback_visualizer_provider.dart';
import 'package:presc/features/playback/ui/providers/speech_to_text_provider.dart';
import 'package:provider/provider.dart';
import 'package:presc/features/vault/ui/pages/vault_home_page.dart';
import 'package:presc/features/vault/ui/providers/vault_prototype_provider.dart';

import 'core/constants/color_constants.dart';
import 'generated/l10n.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      statusBarBrightness: Brightness.light, // for iOS
      statusBarIconBrightness: Brightness.dark, // for Android
    ),
  );
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => PlaybackProvider()),
        ChangeNotifierProvider(create: (context) => SpeechToTextProvider()),
        ChangeNotifierProvider(
          create: (context) => PlaybackVisualizerProvider(),
        ),
        ChangeNotifierProvider(create: (context) => PlaybackTimerProvider()),
        ChangeNotifierProvider(create: (_) => VaultProvider()),
      ],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Presc',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.white,
        splashColor: Platform.isIOS ? Colors.transparent : null,
        splashFactory: Platform.isIOS ? NoSplash.splashFactory : null,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
          iconTheme: IconThemeData(color: ColorConstants.iconColor),
          titleTextStyle: TextStyle(color: Colors.black, fontSize: 20),
        ),
        bottomSheetTheme: BottomSheetThemeData(
          surfaceTintColor: Colors.transparent,
        ),
        dialogTheme: DialogThemeData(
          surfaceTintColor: Colors.transparent,
        ),
        drawerTheme: DrawerThemeData(
          surfaceTintColor: Colors.transparent,
        ),
        popupMenuTheme: PopupMenuThemeData(
          surfaceTintColor: Colors.transparent,
        ),
      ),
      localizationsDelegates: [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: S.delegate.supportedLocales,
      home: const VaultHomePage(),
    );
  }

}
