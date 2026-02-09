plugins {
    kotlin("jvm") version "2.3.0"
}

repositories {
    mavenCentral()
}

dependencies {
    implementation("com.alibaba.fastjson2:fastjson2-kotlin:2.0.60")
    
    implementation("org.jetbrains.kotlin:kotlin-stdlib")
    implementation("org.jetbrains.kotlin:kotlin-reflect")
    
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

tasks.register<JavaExec>("runDebug") {
    group = "application"
    description = "Run in debug mode"
    
    mainClass.set("MainKt")
    classpath = sourceSets.main.get().runtimeClasspath
    
    if (project.hasProperty("args")) {
        args((project.property("args") as String).split(" "))
    }
}

tasks.register<JavaExec>("runRelease") {
    group = "application"
    description = "Run benchmarks with MAXIMUM optimizations"
    
    mainClass.set("MainKt")
    classpath = sourceSets.main.get().runtimeClasspath
    
    jvmArgs = listOf(
        "-server",
        
        "-XX:+UseG1GC",
        "-XX:MaxGCPauseMillis=10",
        "-XX:G1HeapRegionSize=8M",
        "-XX:+UnlockExperimentalVMOptions",
        "-XX:G1NewSizePercent=30",
        "-XX:G1MaxNewSizePercent=50",
        "-XX:G1HeapWastePercent=5",
        "-XX:G1MixedGCCountTarget=8",
        "-XX:InitiatingHeapOccupancyPercent=45",
        
        "-Xms4g",
        "-Xmx4g",
        "-Xss2m",
        "-XX:+AlwaysPreTouch",
        
        "-XX:+OptimizeStringConcat",
        "-XX:+UseCompressedOops",
        "-XX:+UseCompressedClassPointers",
        
        "-Dsun.zip.disableMemoryMapping=true",
        "-Djava.security.egd=file:/dev/./urandom",
        
        "-XX:+DisableExplicitGC",
        "-XX:+UseNUMA",
        "-XX:AutoBoxCacheMax=20000",
        
        "-XX:+PerfDisableSharedMem",
        "-XX:+UseLargePages",
        "-XX:+UseTransparentHugePages",
        
        "-XX:+UseCountedLoopSafepoints",
        "-XX:LoopUnrollLimit=100",
        
        "-XX:MaxInlineSize=325",
        "-XX:FreqInlineSize=325",
        
        "--add-opens=java.base/jdk.internal.misc=ALL-UNNAMED",
        "--add-opens=java.base/sun.nio.ch=ALL-UNNAMED",
        "-Dsun.misc.Unsafe.allowMemoryAccess=true",
    )
        
    if (project.hasProperty("args")) {
        args((project.property("args") as String).split(" "))
    }
}

tasks.register<JavaExec>("runBenchmark") {
    group = "application"
    description = "Run with MAXIMUM optimization for benchmarking"
    
    mainClass.set("MainKt")
    classpath = sourceSets.main.get().runtimeClasspath
    
    jvmArgs = listOf(
        "-server",
        "-XX:+UseG1GC",
        "-XX:MaxGCPauseMillis=1",
        "-Xms4g",
        "-Xmx4g",
        "-XX:+AlwaysPreTouch",
        "-XX:+UseNUMA",
        "-XX:+DisableExplicitGC",
        "-Djava.security.egd=file:/dev/./urandom",
        "--add-opens=java.base/jdk.internal.misc=ALL-UNNAMED",
        "--add-opens=java.base/sun.nio.ch=ALL-UNNAMED",
        "-Dsun.misc.Unsafe.allowMemoryAccess=true"
    )
    
    environment.remove("DEBUG")
    
    if (project.hasProperty("args")) {
        args((project.property("args") as String).split(" "))
    }
    
    doFirst {
        println("⚡ PURE BENCHMARK MODE - минимальные накладные расходы")
    }
}