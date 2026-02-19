ThisBuild / version := "1.0"
ThisBuild / scalaVersion := "3.3.1"

lazy val root = (project in file("."))
  .settings(
    name := "scala3-benchmark",
    libraryDependencies ++= Seq(
      "org.json" % "json" % "20251224",
      "com.alibaba.fastjson2" % "fastjson2" % "2.0.60"
    ),
    Compile / run / fork := true,
    Compile / run / connectInput := true,
    
    scalacOptions ++= Seq(
      "-deprecation",
      "-feature",
      "-unchecked",
      "-Xmax-inlines", "64"
    ),
    assembly / assemblyOutputPath := baseDirectory.value / "target" / "benchmark.jar",
    assembly / assemblyMergeStrategy := {
      case PathList("META-INF", xs @ _*) => MergeStrategy.discard
      case x => MergeStrategy.first
    }
  )