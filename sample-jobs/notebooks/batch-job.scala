// Databricks notebook source
import org.apache.spark.sql.types._
import org.apache.spark.sql.functions._

val schema =
StructType(Seq(
StructField("age",DoubleType),
StructField("workclass",StringType),
StructField("fnlwgt",DoubleType),
StructField("education",StringType),
StructField("education_num",DoubleType),
StructField("marital_status",StringType),
StructField("occupation",StringType),
StructField("relationship",StringType),
StructField("race",StringType),
StructField("sex",StringType),
StructField("capital_gain",DoubleType),
StructField("capital_loss",DoubleType),
StructField("hours_per_week",DoubleType),
StructField("native_country",StringType),
StructField("income",StringType)))

val adult_df = spark.read.
    format("csv")
    .schema(schema)
    .load("dbfs:/databricks-datasets/adult/adult.data")
    .cache


// COMMAND ----------

display(adult_df groupBy('income, 'sex) agg(mean('hours_per_week)))
