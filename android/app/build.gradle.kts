import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Firma de release. Los datos reales viven en android/key.properties y el
// almacen en android/veridia-release.jks; los dos estan en .gitignore.
//
// Existe porque antes el release se firmaba con la clave DEBUG, y esa clave es
// distinta en cada computador: el SHA-1 registrado en Firebase solo valia para
// la maquina donde se genero, asi que el login con Google fallaba en los APK
// compilados en cualquier otra (paso el 2026-08-28 al mover el proyecto).
// Con un keystore propio la huella es siempre la misma, se registra una vez y
// funciona desde donde sea.
//
// Si el archivo no esta (alguien clono el repo sin recibir el keystore), el
// build NO se rompe: cae a la firma debug igual que antes. Pero ese APK vuelve
// a tener el problema del SHA-1, asi que para repartir la app hay que pedir el
// keystore.
val propiedadesFirma = Properties().apply {
    val archivo = rootProject.file("key.properties")
    if (archivo.exists()) archivo.inputStream().use { load(it) }
}
val hayFirmaDeRelease = propiedadesFirma.getProperty("storeFile") != null

android {
    namespace = "com.example.veridia_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.veridia_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hayFirmaDeRelease) {
            create("release") {
                storeFile = rootProject.file(propiedadesFirma.getProperty("storeFile"))
                storePassword = propiedadesFirma.getProperty("storePassword")
                keyAlias = propiedadesFirma.getProperty("keyAlias")
                keyPassword = propiedadesFirma.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hayFirmaDeRelease) {
                signingConfigs.getByName("release")
            } else {
                // Sin keystore: firma debug, para que el build siga saliendo.
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
