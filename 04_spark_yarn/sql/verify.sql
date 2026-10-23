SHOW TABLES IN course_hw4;
SHOW PARTITIONS course_hw4.event_summary;

SELECT event_date, event_count, total_value
FROM course_hw4.event_summary
ORDER BY event_date;

SELECT COUNT(*) AS rows_count, SUM(event_count) AS total_events,
       SUM(total_value) AS total_value
FROM course_hw4.event_summary;
