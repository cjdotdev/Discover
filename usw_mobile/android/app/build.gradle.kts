import java.util.Properties

// La cle Google Maps (Maps SDK for Android) : dans cles.json, hors du depot,
// comme les autres cles de l application. Vide, la carte reste grise.
val cleGoogleMaps: String = rootProject.file("../cles.json").takeIf { it.exists() }?.let {
    (groovy.json.JsonSlurper().parseText(it.readText()) as Map<*, *>)["GOOGLE_MAPS"] as String?
} ?: ""

// La cle de signature de Discover (key.properties et discover-envoi.jks, hors du
// depot). Sans elle, la version de sortie est signee avec la cle de debug.
val cleSignature = Properties().apply {
    rootProject.file("key.properties").takeIf { it.exists() }?.reader()?.use { load(it) }
}

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Firebase (les notifications) : google-services.json, hors du depot comme cles.json.
// Sans lui, l application se construit, et les notifications restent dans l appli.
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}

android {
    namespace = "bj.usw"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "bj.usw"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["cleGoogleMaps"] = cleGoogleMaps
    }

    signingConfigs {
        if (!cleSignature.isEmpty) {
            create("envoi") {
                keyAlias = cleSignature.getProperty("keyAlias")
                keyPassword = cleSignature.getProperty("keyPassword")
                storeFile = file(cleSignature.getProperty("storeFile"))
                storePassword = cleSignature.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("envoi") ?: signingConfigs.getByName("debug")
        }
    }
}

// Version de production : seulement les telephones (ARM 32 et 64 bits). Les bibliotheques x86_64
// (emulateurs de PC, dont 12 Mo de ML Kit) ne servent a personne et alourdissaient l APK de 36 Mo.
// (Un filtre ndk.abiFilters ne suffit pas : Flutter y ajoute lui-meme x86_64.)
androidComponents {
    onVariants(selector().withBuildType("release")) { variante ->
        variante.packaging.jniLibs.excludes.add("lib/x86_64/**")
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

// ML Kit (etiquettes) tire l ancien firebase-iid via linkfirebase, qui ne sert
// qu aux modeles telecharges : firebase-messaging contient deja ses classes.
configurations.all {
    exclude(group = "com.google.firebase", module = "firebase-iid")
}

dependencies {
    // La fenetre « Activer la localisation » (deja dans l application via geolocator).
    implementation("com.google.android.gms:play-services-location:21.2.0")
    // Alleger une video avant l envoi, avec la puce du telephone (Optimiseur.kt) : la version de
    // Media3 du lecteur video (video_player), sinon elles se contredisent.
    implementation("androidx.media3:media3-transformer:1.9.2")
    implementation("androidx.media3:media3-effect:1.9.2")
    implementation("androidx.media3:media3-common:1.9.2")
}
