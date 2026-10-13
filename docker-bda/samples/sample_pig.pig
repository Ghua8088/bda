-- Sample Pig script reading dataset.csv
records = LOAD '/workspace/dataset.csv' USING PigStorage(',') AS (col1:chararray, col2:chararray, col3:chararray);
top5 = LIMIT records 5;
DUMP top5;
