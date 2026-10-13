-- Sample Hive script
CREATE DATABASE IF NOT EXISTS bda_demo;
USE bda_demo;

CREATE TABLE IF NOT EXISTS sample_data (
    id INT,
    tool_name STRING,
    purpose STRING
)
ROW FORMAT DELIMITED
FIELDS TERMINATED BY ',';

INSERT INTO sample_data VALUES
(1, 'Hadoop', 'Distributed Storage and Compute'),
(2, 'Pig', 'High-level Data Flow Language'),
(3, 'Hive', 'Data Warehouse and SQL Abstraction'),
(4, 'HBase', 'NoSQL Column-Oriented Database');

SELECT * FROM sample_data;
