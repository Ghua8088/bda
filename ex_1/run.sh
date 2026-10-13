#!/usr/bin/env bash
# ==============================================================================
# Exercise 1: MapReduce Word Count with Hadoop Streaming
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "======================================================================"
echo "  Exercise 1: MapReduce Word Count (Hadoop Streaming on YARN)         "
echo "======================================================================"

echo ""
echo "[1/4] Uploading sample.txt to HDFS (/ex_1/input)..."
hdfs dfs -mkdir -p /ex_1/input
hdfs dfs -put -f "${SCRIPT_DIR}/sample.txt" /ex_1/input/

echo "[2/4] Removing previous HDFS output directory (/ex_1/output)..."
hdfs dfs -rm -r -f /ex_1/output 2>/dev/null || true

echo "[3/4] Submitting MapReduce Streaming job to YARN..."
STREAMING_JAR="/usr/local/hadoop/share/hadoop/tools/lib/hadoop-streaming-2.9.2.jar"

hadoop jar "${STREAMING_JAR}" \
  -input /ex_1/input/sample.txt \
  -output /ex_1/output \
  -mapper "python /workspace/ex_1/mapper1.py" \
  -reducer "python /workspace/ex_1/reducer1.py" \
  -file "/workspace/ex_1/mapper1.py" \
  -file "/workspace/ex_1/reducer1.py"

echo ""
echo "[4/4] Output results from HDFS (/ex_1/output/part-00000):"
echo "----------------------------------------------------------------------"
hdfs dfs -cat /ex_1/output/part-00000 | head -n 25
echo "----------------------------------------------------------------------"
echo "🎉 Exercise 1 completed successfully!"
