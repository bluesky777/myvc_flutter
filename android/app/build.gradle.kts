import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
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
    namespace = "com.micolevirtual.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Lo exige flutter_local_notifications, que es quien pinta el aviso
        // cuando llega con la app abierta —FCM ahí no dibuja nada—. Su AAR lo
        // pide aunque no se use la parte que lo necesita de verdad, que es
        // programar avisos a una hora: sin esto el build ni empieza.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.micolevirtual.app"
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

dependencies {
    // La otra mitad de `isCoreLibraryDesugaringEnabled`: la biblioteca con la
    // que se rellenan las clases de Java 8 que no trae un Android viejo.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
