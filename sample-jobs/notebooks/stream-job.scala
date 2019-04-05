// Databricks notebook source
package com.example.samplejob

import com.microsoft.pnp.logging.Log4jConfiguration
import org.apache.spark.internal.Logging
import org.apache.spark.metrics.UserMetricsSystems
import org.apache.spark.sql.SparkSession
import org.apache.spark.sql.functions.window
import org.apache.spark.sql.types.{StringType, StructType, TimestampType}

object StreamingQueryListenerSampleJob extends Logging {

  private final val METRICS_NAMESPACE = "streamingquerylistenersamplejob"
  private final val COUNTER_NAME = "rowcounter"

  def runStreamingJob(spark: SparkSession): Unit = {

    Log4jConfiguration.configure("/dbfs/monitoring-tutorial/log4j.properties")

    logTrace("Trace message from StreamingQueryListenerSampleJob")
    logDebug("Debug message from StreamingQueryListenerSampleJob")
    logInfo("Info message from StreamingQueryListenerSampleJob")
    logWarning("Warning message from StreamingQueryListenerSampleJob")
    logError("Error message from StreamingQueryListenerSampleJob")

    // this path has sample files provided by databricks for trying out purpose
    val inputPath = "/databricks-datasets/structured-streaming/events/"

    val jsonSchema = new StructType().add("time", TimestampType).add("action", StringType)

    val driverMetricsSystem = UserMetricsSystems
        .getMetricSystem(METRICS_NAMESPACE, builder => {
          builder.registerCounter(COUNTER_NAME)
        })

    driverMetricsSystem.counter(COUNTER_NAME).inc

    val streamingInputDF =
      spark
        .readStream
        .schema(jsonSchema) // Set the schema of the JSON data
        .option("maxFilesPerTrigger", 1) // Treat a sequence of files as a stream by picking one file at a time
        .json(inputPath)

    driverMetricsSystem.counter(COUNTER_NAME).inc(5)

    import spark.implicits._
    val streamingCountsDF =
      streamingInputDF
        .groupBy($"action", window($"time", "1 hour"))
        .count()

    driverMetricsSystem.counter(COUNTER_NAME).inc(10)

    val query =
      streamingCountsDF
        .writeStream
        .format("memory") // memory = store in-memory table (for testing only in Spark 2.0)
        .queryName("counts") // counts = name of the in-memory table
        .outputMode("complete") // complete = all the counts should be in the table
        .start()
  }
}

// COMMAND ----------

com.example.samplejob.StreamingQueryListenerSampleJob.runStreamingJob(spark)
