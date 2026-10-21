SHOW PARTITIONS course_hw3.events;

SELECT event_date, COUNT(*) AS rows_count
FROM course_hw3.events
GROUP BY event_date
ORDER BY event_date;

SELECT COUNT(*) AS total_rows
FROM course_hw3.events;
