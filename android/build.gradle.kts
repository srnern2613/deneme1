allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// `flutter_timezone` (ve benzeri, henüz güncellenmemiş bazı Flutter
// eklentileri) kendi Kotlin derleme hedefini (1.8) `app` modülünün Java
// hedefinden (17) farklı bırakıyor — bu da "Inconsistent JVM-target
// compatibility" build hatasına yol açıyor. Kendi kodumuz DEĞİL, pub
// cache'teki eklenti kodu olduğu için düzenleyemiyoruz; bunun yerine TÜM
// alt projelerin (app dahil) Java/Kotlin derleme hedefini burada, merkezi
// olarak 17'ye zorluyoruz — yaygın, resmî olarak önerilen çözüm
// (bkz. https://kotl.in/gradle/jvm/target-validation).
//
// NOT: ilk denemede burada düz `subprojects { afterEvaluate { ... } }`
// kullanılmıştı ama yukarıdaki `evaluationDependsOn(":app")` satırı
// ":app" projesini bu blok çalışana kadar ZATEN tam olarak evaluate
// ettiğinden, `:app` için `afterEvaluate` çağrısı "Cannot run
// Project.afterEvaluate(Action) when the project is already evaluated"
// hatasıyla patlıyordu. Çözüm: proje zaten evaluate olmuşsa bloğu HEMEN
// çalıştır, olmamışsa `afterEvaluate` ile beklet.
fun Project.applyJvm17ToKotlinPlugins() {
    // ":app" burada BİLEREK atlanıyor: kendi build.gradle.kts'inde zaten
    // Java 17 ayarlıyor VE bu bloğun çalıştığı ana kadar o ayar Gradle
    // tarafından "finalize" edilmiş oluyor — tekrar dokunmaya çalışmak
    // "sourceCompatibility has been finalized" hatası veriyor. Bu blok
    // sadece asıl sorunun kaynağı olan EKLENTİ alt projeleri
    // (flutter_timezone gibi) için gerekli.
    if (name == "app") return

    extensions.findByType<com.android.build.gradle.BaseExtension>()?.apply {
        compileOptions {
            sourceCompatibility = JavaVersion.VERSION_17
            targetCompatibility = JavaVersion.VERSION_17
        }
    }
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }
}

subprojects {
    if (state.executed) {
        applyJvm17ToKotlinPlugins()
    } else {
        afterEvaluate {
            applyJvm17ToKotlinPlugins()
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
