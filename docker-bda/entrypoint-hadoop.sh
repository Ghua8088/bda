#!/usr/bin/env bash
set -e

echo "=== [1/6] Starting Hadoop & Spark Daemons ==="
# Pass EOF to /dev/null so trailing /bin/bash in /etc/bootstrap.sh does not block
/etc/bootstrap.sh < /dev/null

echo "=== [2/6] Silencing duplicate SLF4J binding warning ==="
if [ -f /usr/local/hive/lib/log4j-slf4j-impl-2.6.2.jar ]; then
  mv /usr/local/hive/lib/log4j-slf4j-impl-2.6.2.jar /usr/local/hive/lib/log4j-slf4j-impl-2.6.2.jar.bak 2>/dev/null || true
fi

echo "=== [3/6] Configuring Hive Metastore ==="
mkdir -p /var/lib/hive
rm -f /var/lib/hive/metastore_db/*.lck 2>/dev/null || true

cat << 'EOF' > /usr/local/hive/conf/hive-site.xml
<configuration>
  <property>
    <name>javax.jdo.option.ConnectionURL</name>
    <value>jdbc:derby:/var/lib/hive/metastore_db;create=true</value>
  </property>
  <property>
    <name>javax.jdo.option.ConnectionDriverName</name>
    <value>org.apache.derby.jdbc.EmbeddedDriver</value>
  </property>
  <property>
    <name>hive.metastore.uris</name>
    <value>thrift://localhost:9083</value>
  </property>
  <property>
    <name>hive.metastore.warehouse.dir</name>
    <value>/user/hive/warehouse</value>
  </property>
  <property>
    <name>hive.metastore.schema.verification</name>
    <value>false</value>
  </property>
</configuration>
EOF

echo "=== [4/6] Initializing Derby Schema if needed ==="
if [ ! -d /var/lib/hive/metastore_db/seg0 ]; then
  echo "Metastore schema not found. Initializing..."
  /usr/local/hive/bin/schematool -dbType derby -initSchema || true
else
  echo "Metastore schema already initialized."
fi

echo "=== [5/6] Setting HDFS directory permissions ==="
hdfs dfs -mkdir -p /user/hive/warehouse /tmp 2>/dev/null || true
hdfs dfs -chmod -R 777 /user/hive /tmp 2>/dev/null || true

echo "=== [6/6] Starting Hive Metastore Service ==="
nohup /usr/local/hive/bin/hive --service metastore > /tmp/hive-metastore.log 2>&1 &

echo "Waiting for Hive Metastore to listen on port 9083..."
while ! nc -z localhost 9083; do
  sleep 1
done

echo "=== Big Data Analytics Container Ready ==="
tail -f /dev/null
