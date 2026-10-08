import java.security.MessageDigest
import org.gradle.api.artifacts.component.ModuleComponentIdentifier
import org.gradle.api.artifacts.component.ProjectComponentIdentifier
import org.gradle.api.attributes.Attribute

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.loquiris"
    compileSdk = 36
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.loquiris"
        minSdk = 29
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    buildTypes {
        debug {
            applicationIdSuffix = ".debug"
        }
        release {
            // Release signing is supplied outside source control by the release workflow.
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    testImplementation("junit:junit:4.13.2")
    androidTestImplementation("androidx.test:core:1.7.0")
    androidTestImplementation("androidx.test:rules:1.7.0")
    androidTestImplementation("androidx.test.ext:junit:1.3.0")
}

flutter {
    source = "../.."
}

val releaseRuntimeClasspath =
    providers.provider { configurations.getByName("releaseRuntimeClasspath") }
val androidArtifactType = Attribute.of("artifactType", String::class.java)
val releaseRuntimeArtifacts =
    releaseRuntimeClasspath.map { configuration ->
        configuration.incoming
            .artifactView {
                attributes.attribute(androidArtifactType, "android-classes-jar")
            }.artifacts
    }

tasks.register("writeReleaseDependencyInventory") {
    group = "reporting"
    description = "Writes the hashed Android release runtime dependency inventory."
    inputs.files(releaseRuntimeArtifacts.map { artifacts -> artifacts.artifactFiles })
    val inventoryFile =
        rootProject.layout.buildDirectory.file(
            "third_party_notices/android_release_dependencies.json",
        )
    outputs.file(inventoryFile)

    doLast {
        fun quoted(value: String): String =
            buildString {
                append('"')
                value.forEach { character ->
                    when (character) {
                        '"' -> append("\\\"")
                        '\\' -> append("\\\\")
                        '\b' -> append("\\b")
                        '\u000c' -> append("\\f")
                        '\n' -> append("\\n")
                        '\r' -> append("\\r")
                        '\t' -> append("\\t")
                        else ->
                            if (character.code < 0x20) {
                                append("\\u%04x".format(character.code))
                            } else {
                                append(character)
                            }
                    }
                }
                append('"')
        }

        fun sha256(file: File): String {
            val digest = MessageDigest.getInstance("SHA-256")
            file.inputStream().buffered().use { input ->
                val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
                while (true) {
                    val count = input.read(buffer)
                    if (count < 0) break
                    digest.update(buffer, 0, count)
                }
            }
            return digest.digest().joinToString("") { byte: Byte -> "%02x".format(byte) }
        }

        val artifacts =
            releaseRuntimeArtifacts
                .get()
                .artifacts
                .map { artifact ->
                    val component = artifact.id.componentIdentifier
                    val (group, name, version) =
                        when (component) {
                            is ModuleComponentIdentifier ->
                                Triple(component.group, component.module, component.version)
                            is ProjectComponentIdentifier ->
                                Triple(
                                    "project",
                                    component.projectPath.trimStart(':').replace(':', '-'),
                                    "workspace",
                                )
                            else ->
                                throw GradleException(
                                    "Unsupported release component identifier: ${component.displayName}",
                                )
                        }
                    val extension = artifact.file.extension.ifEmpty { "jar" }
                    val coordinate = "$group:$name:$version"
                    mapOf(
                        "coordinate" to coordinate,
                        "group" to group,
                        "name" to name,
                        "version" to version,
                        "extension" to extension,
                        "classifier" to null,
                        "bytes" to artifact.file.length(),
                        "sha256" to sha256(artifact.file),
                    )
                }.sortedBy { artifact -> artifact.getValue("coordinate") as String }

        val contents =
            buildString {
                append("{\"schemaVersion\":1,")
                append("\"configuration\":\"releaseRuntimeClasspath\",")
                append("\"artifacts\":[")
                artifacts.forEachIndexed { index, artifact ->
                    if (index > 0) append(',')
                    append('{')
                    append("\"coordinate\":${quoted(artifact.getValue("coordinate") as String)},")
                    append("\"group\":${quoted(artifact.getValue("group") as String)},")
                    append("\"name\":${quoted(artifact.getValue("name") as String)},")
                    append("\"version\":${quoted(artifact.getValue("version") as String)},")
                    append("\"extension\":${quoted(artifact.getValue("extension") as String)},")
                    val classifier = artifact["classifier"] as String?
                    append("\"classifier\":${classifier?.let(::quoted) ?: "null"},")
                    append("\"bytes\":${artifact.getValue("bytes")},")
                    append("\"sha256\":${quoted(artifact.getValue("sha256") as String)}")
                    append('}')
                }
                append("]}\n")
            }
        val output = inventoryFile.get().asFile
        output.parentFile.mkdirs()
        output.writeText(contents)
    }
}
