import 'dart:io';

/// Adds release-signing support to the stock Flutter Kotlin Gradle template.
/// It is intentionally run only in CI after the native host is generated and
/// only when the signing secrets have been restored.
void main() {
  final file = File('android/app/build.gradle.kts');
  var source = file.readAsStringSync();
  const marker = '// SHIYE_RELEASE_SIGNING';
  if (source.contains(marker)) return;

  const import = "import java.util.Properties\n";
  if (!source.startsWith(import)) {
    source = '$import$source';
  }

  const signing = '''
val shiYeKeystoreProperties = Properties()
val shiYeKeystorePropertiesFile = rootProject.file("key.properties")
if (shiYeKeystorePropertiesFile.exists()) {
    shiYeKeystorePropertiesFile.inputStream().use(shiYeKeystoreProperties::load)
}

// SHIYE_RELEASE_SIGNING
''';
  source = source.replaceFirst('android {', '$signing\nandroid {');

  const releaseConfig = '''
    signingConfigs {
        create("release") {
            keyAlias = shiYeKeystoreProperties["keyAlias"] as String
            keyPassword = shiYeKeystoreProperties["keyPassword"] as String
            storeFile = file(shiYeKeystoreProperties["storeFile"] as String)
            storePassword = shiYeKeystoreProperties["storePassword"] as String
        }
    }
''';
  source = source.replaceFirst('    buildTypes {', '$releaseConfig\n    buildTypes {');
  source = source.replaceFirst(
    'signingConfig = signingConfigs.getByName("debug")',
    'signingConfig = signingConfigs.getByName("release")',
  );
  file.writeAsStringSync(source);
}
