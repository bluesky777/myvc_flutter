import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// La clave con la que se firma el release. Vive fuera del repositorio —el
// .gitignore la excluye— porque lleva contraseñas: quien compile para Play
// crea android/key.properties con keyAlias, keyPassword, storeFile y
// storePassword. Sin ese archivo se firma con la de depuración, que sirve para
// probar en un teléfono pero que Play rechaza.
val propiedadesDeFirma = Properties()
val archivoDeFirma = rootProject.file("key.properties")
if (archivoDeFirma.exists()) {
    archivoDeFirma.inputStream().use { propiedadesDeFirma.load(it) }
}

android {
    namespace = "com.app.micolevirtual.myvc_flutter"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.app.micolevirtual.myvc_flutter"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (archivoDeFirma.exists()) {
            create("release") {
                keyAlias = propiedadesDeFirma.getProperty("keyAlias")
                keyPassword = propiedadesDeFirma.getProperty("keyPassword")
                storeFile = propiedadesDeFirma.getProperty("storeFile")?.let { file(it) }
                storePassword = propiedadesDeFirma.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            val firmaDeVerdad = signingConfigs.findByName("release")
            if (firmaDeVerdad == null) {
                logger.error(
                    "AVISO: no hay android/key.properties, así que este release " +
                        "va firmado con la clave de depuración. Google Play no lo acepta."
                )
            }
            signingConfig = firmaDeVerdad ?: signingConfigs.getByName("debug")
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
