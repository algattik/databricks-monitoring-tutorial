// Databricks notebook source
package com.example.samplejob

import com.microsoft.pnp.logging.Log4jConfiguration
import org.apache.spark.internal.Logging
import org.apache.spark.metrics.UserMetricsSystems
import org.apache.spark.sql.SparkSession
import org.apache.spark.sql.functions.window
import org.apache.spark.sql.types.{StringType, StructType, TimestampType}

object SumNumbers extends Logging {

  private final val METRICS_NAMESPACE = "streamingquerylistenersamplejob"
  private final val COUNTER_NAME = "rowcounter"

  def computeSumOfNumbersFromOneTo(value: Long, spark: SparkSession): Long = {

    Log4jConfiguration.configure("/dbfs/log4j.properties")

    logTrace("Trace message from StreamingQueryListenerSampleJob")
    logDebug("Debug message from StreamingQueryListenerSampleJob")
    logInfo("Info message from StreamingQueryListenerSampleJob")
    logWarning("Warning message from StreamingQueryListenerSampleJob")
    logError("Error message from StreamingQueryListenerSampleJob")

    val driverMetricsSystem = UserMetricsSystems
        .getMetricSystem(METRICS_NAMESPACE, builder => {
          builder.registerCounter(COUNTER_NAME)
        })

    driverMetricsSystem.counter(COUNTER_NAME).inc

    val sumOfNumbers = spark.range(value + 1).reduce(_ + _)
    
    driverMetricsSystem.counter(COUNTER_NAME).inc(5)
    
    return sumOfNumbers
  }
}

// COMMAND ----------

com.example.samplejob.SumNumbers.computeSumOfNumbersFromOneTo(100, spark)
