// Databricks notebook source
import org.apache.spark.sql.functions.window
import org.apache.spark.sql.types.{StringType, StructType, TimestampType}

// this path has sample files provided by Databricks for test purposes
val inputPath = "/databricks-datasets/structured-streaming/events/"

val jsonSchema = new StructType().add("time", TimestampType).add("action", StringType)

val streamingInputDF =
  spark
    .readStream
    .schema(jsonSchema) // Set the schema of the JSON data
    .option("maxFilesPerTrigger", 1) // Treat a sequence of files as a stream by picking one file at a time
    .json(inputPath)

import spark.implicits._

val streamingCountsDF =
  streamingInputDF
    .groupBy($"action", window($"time", "1 hour"))
    .count()

val query =
  streamingCountsDF
    .writeStream
    .format("memory") // memory = store in-memory table (for testing only in Spark 2.0)
    .queryName("counts") // counts = name of the in-memory table
    .outputMode("complete") // complete = all the counts should be in the table
    .start()
