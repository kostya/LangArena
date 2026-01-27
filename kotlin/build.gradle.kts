plugins {
    kotlin("jvm") version "2.3.0"
}

repositories {
    mavenCentral()
}

dependencies {
    // Будущие зависимости здесь
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.10.2")
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.10.0")
    implementation("org.json:json:20251224")
}

java {
    sourceCompatibility = JavaVersion.VERSION_25
    targetCompatibility = JavaVersion.VERSION_25
}

tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile> {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_25)
    }
}

// Fat JAR
tasks.register<Jar>("fatJar") {
    archiveBaseName.set("benchmarks")
    
    manifest {
        attributes["Main-Class"] = "MainKt"
    }
    
    from(sourceSets.main.get().output)
    
    dependsOn(configurations.runtimeClasspath)
    from({
        configurations.runtimeClasspath.get()
            .filter { it.name.endsWith("jar") }
            .map { zipTree(it) }
    })
    
    duplicatesStrategy = DuplicatesStrategy.EXCLUDE
}

// Задачи запуска
tasks.register<JavaExec>("runDebug") {
    group = "application"
    description = "Run in debug mode"
    
    mainClass.set("MainKt")
    classpath = sourceSets.main.get().runtimeClasspath
    
    // environment("DEBUG", "1")
    
    if (project.hasProperty("args")) {
        args((project.property("args") as String).split(" "))
    }
}

tasks.register<JavaExec>("runRelease") {
    group = "application"
    description = "Run benchmarks with MAXIMUM optimizations"
    
    mainClass.set("MainKt")
    classpath = sourceSets.main.get().runtimeClasspath
    
    // ВСЕ оптимизации для бенчмарков
    jvmArgs = listOf(
        // 1. Режим JVM
        "-server",
        
        // 2. Сборщик мусора (G1 с агрессивными настройками)
        "-XX:+UseG1GC",
        "-XX:MaxGCPauseMillis=10",
        "-XX:G1HeapRegionSize=8M",
        "-XX:+UnlockExperimentalVMOptions",
        "-XX:G1NewSizePercent=30",
        "-XX:G1MaxNewSizePercent=50",
        "-XX:G1HeapWastePercent=5",
        "-XX:G1MixedGCCountTarget=8",
        "-XX:InitiatingHeapOccupancyPercent=45",
        
        // 3. Память (предварительное выделение)
        "-Xms4g",  // Начальная куча 4GB
        "-Xmx4g",  // Максимальная куча 4GB
        "-Xss2m",  // Размер стека потока
        "-XX:+AlwaysPreTouch",  // Предварительное выделение всей памяти
        
        // 4. JIT компиляция (максимальная оптимизация)
        "-XX:+OptimizeStringConcat",
        "-XX:+UseCompressedOops",
        "-XX:+UseCompressedClassPointers",
        
        // 5. Библиотеки
        "-Dsun.zip.disableMemoryMapping=true",  // Быстрее ZIP
        "-Djava.security.egd=file:/dev/./urandom",  // Быстрый random
        
        // 6. Отключаем всё лишнее
        "-XX:+DisableExplicitGC",  // Игнорируем System.gc()
        "-XX:+UseNUMA",  // Оптимизация для многоядерных систем
        "-XX:AutoBoxCacheMax=20000",  // Кэш для autoboxing
        
        // 7. Для Linux/Unix
        "-XX:+PerfDisableSharedMem",  // Отключаем shared memory для perf
        "-XX:+UseLargePages",  // Используем large pages (если настроено)
        "-XX:+UseTransparentHugePages",  // Transparent huge pages
        
        // 8. Оптимизация циклов
        "-XX:+UseCountedLoopSafepoints",
        "-XX:LoopUnrollLimit=100",
        
        // 9. Инлайнинг
        "-XX:MaxInlineSize=325",  // Максимальный размер для инлайнинга
        "-XX:FreqInlineSize=325",  // Размер для частых методов
        
        // 10. Профилирование JIT (можно убрать для чистого запуска)
        // "-XX:+PrintCompilation",  // Показывает что JIT компилирует
        // "-XX:+PrintInlining",     // Показывает инлайнинг
    )
    
    // Опционально: если система поддерживает
    // "-XX:UseAVX=3",  // AVX инструкции если CPU поддерживает
    // "-XX:+UseAES",   // AES инструкции если есть
    
    if (project.hasProperty("args")) {
        args((project.property("args") as String).split(" "))
    }
    
    doFirst {
        println("🚀 MAXIMUM OPTIMIZATION MODE for benchmarks")
        println("   JVM: Server mode with all optimizations")
        println("   GC: G1 with 10ms target pause")
        println("   Memory: 4GB heap pre-allocated")
        println("   JIT: Aggressive inlining and optimization")
    }
}

tasks.register<JavaExec>("runBenchmark") {
    group = "application"
    description = "Run with MAXIMUM optimization for benchmarking"
    
    mainClass.set("MainKt")
    classpath = sourceSets.main.get().runtimeClasspath
    
    // Минимум флагов для чистого измерения
    jvmArgs = listOf(
        "-server",
        "-XX:+UseG1GC",
        "-XX:MaxGCPauseMillis=1",  // Супер агрессивный GC
        "-Xms4g",
        "-Xmx4g",
        "-XX:+AlwaysPreTouch",
        "-XX:+UseNUMA",
        "-XX:+DisableExplicitGC",
        "-Djava.security.egd=file:/dev/./urandom"
    )
    
    // Минимизируем всё кроме производительности
    environment.remove("DEBUG")
    
    if (project.hasProperty("args")) {
        args((project.property("args") as String).split(" "))
    }
    
    doFirst {
        println("⚡ PURE BENCHMARK MODE - минимальные накладные расходы")
    }
}