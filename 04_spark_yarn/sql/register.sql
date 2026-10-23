CREATE DATABASE IF NOT EXISTS course_hw4;

CREATE EXTERNAL TABLE IF NOT EXISTS course_hw4.event_summary (
    event_count BIGINT,
    total_value BIGINT
)
PARTITIONED BY (event_date STRING)
STORED AS PARQUET
LOCATION '${hivevar:output_path}';

MSCK REPAIR TABLE course_hw4.event_summary;
