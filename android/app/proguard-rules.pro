# Flutter Wrapper and Engine Keep Rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Flutter Local Notifications Keep Rules
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# Mobile Scanner Keep Rules
-keep class dev.steenbakker.mobile_scanner.** { *; }

# Print Bluetooth Thermal Keep Rules
-keep class com.ext2.print_bluetooth_thermal.** { *; }

# Flutter Secure Storage Keep Rules
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# Drift / Sqlite3 Keep Rules
-keep class org.sqlite.** { *; }

# Suppress harmless third-party inspection warnings
-dontwarn io.flutter.embedding.**
-dontwarn com.google.android.gms.**
