import sys

from pyspark.sql import SparkSession, functions as F

input_path, output_path = sys.argv[1:3]
spark = SparkSession.builder.appName("course_hw4").getOrCreate()

if spark.sparkContext.master != "yarn":
    raise RuntimeError("Spark must run on YARN")

print(f"YARN application: {spark.sparkContext.applicationId}", flush=True)
print(f"Reading: {input_path}", flush=True)

events = spark.read.option("basePath", input_path).csv(input_path)
clean = events.select(
    F.col("_c0").cast("int").alias("event_id"),
    F.col("_c1").cast("long").alias("event_value"),
    F.col("event_date").cast("string").alias("event_date"),
).filter((F.col("event_id") > 0) & (F.col("event_value") > 0))

if clean.limit(1).count() == 0:
    raise RuntimeError("No valid input rows")

summary = clean.groupBy("event_date").agg(
    F.count("*").alias("event_count"),
    F.sum("event_value").alias("total_value"),
)

summary.orderBy("event_date").show()
summary.write.mode("overwrite").partitionBy("event_date").parquet(output_path)

print(f"Saved: {output_path}", flush=True)
spark.stop()
