CREATE DATABASE IF NOT EXISTS course_hw3;

CREATE EXTERNAL TABLE IF NOT EXISTS course_hw3.events (
    event_id INT,
    event_value INT
)
PARTITIONED BY (event_date STRING)
ROW FORMAT DELIMITED
FIELDS TERMINATED BY ','
STORED AS TEXTFILE
LOCATION '${hivevar:table_location}';

ALTER TABLE course_hw3.events ADD IF NOT EXISTS
    PARTITION (event_date='2026-10-01')
    LOCATION '${hivevar:table_location}/event_date=2026-10-01';

ALTER TABLE course_hw3.events ADD IF NOT EXISTS
    PARTITION (event_date='2026-10-02')
    LOCATION '${hivevar:table_location}/event_date=2026-10-02';
