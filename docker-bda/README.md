# Big Data Analytics (BDA) Environment
### Apache Pig, Apache Hive & Apache HBase

A lightweight, zero-bloat Big Data environment using your existing containers and packages without pulling extra heavy Docker images.

---

## 🛠️ CLI Tools & How to Run

Convenience scripts are in `./bin/`:

### 1. Apache HBase
* **Status**: Running inside container `bda-hbase`.
* **Web UI**: [http://localhost:16010](http://localhost:16010)
* **Open Interactive Shell**:
  ```bash
  ./bin/hbase
  ```
* **Sample Commands**:
  ```ruby
  create 'students', 'info', 'marks'
  put 'students', '1', 'info:name', 'Alice'
  scan 'students'
  get 'students', '1'
  exit
  ```

---

### 2. Apache Pig (0.17.0)
* **Status**: Running inside `bda-hbase` with OpenJDK 8 and Hadoop libraries.
* **Interactive Grunt Shell (Local Mode)**:
  ```bash
  ./bin/pig -x local
  ```
* **Run a Pig Script**:
  ```bash
  ./bin/pig -x local samples/sample_pig.pig
  ```
* **Run Inline Pig Latin**:
  ```bash
  ./bin/pig -x local -e "A = LOAD '/workspace/dataset.csv' USING PigStorage(',') AS (c1:chararray, c2:chararray); B = LIMIT A 3; DUMP B;"
  ```

---

### 3. Apache Hive
* **Status**: Integrated Hive metastore & HiveQL engine.
* **Interactive Hive Shell**:
  ```bash
  ./bin/hive
  ```
* **Run a SQL Script**:
  ```bash
  ./bin/hive -f samples/sample_hive.sql
  ```
* **Run Inline HiveQL**:
  ```bash
  ./bin/hive -e "SHOW DATABASES;"
  ./bin/hive -e "SELECT * FROM bda_demo.sample_data;"
  ```

---

### 4. Apache Hadoop (HDFS & MapReduce / YARN)
* **Status**: Running inside container `bda-hadoop`.
* **Web UI**:
  * HDFS NameNode: [http://localhost:50070](http://localhost:50070)
  * YARN ResourceManager: [http://localhost:8088](http://localhost:8088)
* **CLI Launchers** (run anywhere via global CLI or `./bin/`):
  ```bash
  # Check Hadoop version
  hadoop version

  # Run HDFS commands
  hdfs dfs -ls /
  hdfs dfs -mkdir -p /data
  hdfs dfs -put sample.csv /data/

  # Run MapReduce Jobs
  hadoop jar /usr/local/hadoop/share/hadoop/mapreduce/hadoop-mapreduce-examples-2.9.2.jar wordcount /data/sample.csv /data/output

  # Enter container shell
  ./bin/enter-hadoop
  ```

## 📁 Directory Layout

```text
/home/ghua/bda/docker-bda/
├── bin/
│   ├── hadoop      # Hadoop launcher
│   ├── hdfs        # HDFS launcher
│   ├── enter-hadoop # Interactive Hadoop container bash terminal
│   ├── hbase       # HBase Shell launcher
│   ├── pig         # Apache Pig launcher
│   ├── hive        # Hive SQL launcher
│   └── enter-hbase # Interactive HBase container bash terminal
├── samples/
│   ├── sample_pig.pig   # Sample Pig Latin script
│   ├── sample_hive.sql  # Sample Hive table creation & query
│   └── sample_hbase.txt # Sample HBase table commands
└── pig/                 # Apache Pig binaries & libraries
```
