#!/usr/bin/env bash

set -euxo pipefail

generate_database_config(){
  cat << XML
<property>
  <name>javax.jdo.option.ConnectionDriverName</name>
  <value>${DATABASE_DRIVER}</value>
</property>
<property>
  <name>javax.jdo.option.ConnectionURL</name>
  <value>jdbc:${DATABASE_TYPE_JDBC}://${DATABASE_HOST}:${DATABASE_PORT}/${DATABASE_DB}</value>
</property>
<property>
  <name>javax.jdo.option.ConnectionUserName</name>
  <value>${DATABASE_USER}</value>
</property>
<property>
  <name>javax.jdo.option.ConnectionPassword</name>
  <value>${DATABASE_PASSWORD}</value>
</property>
<!--
  #    <property>
  #        <name>javax.jdo.option.ConnectionDriverName</name>
  #        <value>com.mysql.cj.jdbc.Driver</value>
  #    </property>
  #
  #    <property>
  #        <name>javax.jdo.option.ConnectionURL</name>
  #        <value>jdbc:mysql://mariadb:3306/metastore_db</value>
  #    </property>
  #
  #    <property>
  #        <name>javax.jdo.option.ConnectionUserName</name>
  #        <value>admin</value>
  #    </property>
  #
  #    <property>
  #        <name>javax.jdo.option.ConnectionPassword</name>
  #        <value>admin</value>
  #    </property>
-->
XML
}

generate_hive_site_config(){
  database_config=$(generate_database_config)
  cat << XML > "$1"
<configuration>
$database_config
</configuration>
XML
}

generate_metastore_site_config(){
  database_config=$(generate_database_config)
  cat << XML > "$1"
<configuration>
 <property>
        <name>metastore.thrift.uris</name>
        <value>thrift://hive-metastore:9083</value>
        <description>Thrift URI for the remote metastore. Used by metastore client to connect to remote metastore.</description>
    </property>
    <property>
        <name>metastore.task.threads.always</name>
        <value>org.apache.hadoop.hive.metastore.events.EventCleanerTask,org.apache.hadoop.hive.metastore.MaterializationsCacheCleanerTask</value>
    </property>
    <property>
        <name>metastore.expression.proxy</name>
        <value>org.apache.hadoop.hive.metastore.DefaultPartitionExpressionProxy</value>
    </property>

    <property>
        <name>fs.s3a.access.key</name>
        <value>minio</value>
    </property>
    <property>
        <name>fs.s3a.secret.key</name>
        <value>minio123</value>
    </property>
    <property>
        <name>fs.s3a.endpoint</name>
        <value>http://minio:9000</value>
    </property>
    <property>
        <name>fs.s3a.path.style.access</name>
        <value>true</value>
    </property>

</configuration>
XML
}


generate_core_site_config(){
#  custom_endpoint_configs=$(generate_s3_custom_endpoint)
custom_endpoint_configs=""
  cat << XML > "$1"
<configuration>

    <property>
        <name>fs.defaultFS</name>
        <value>s3a://minio:9000</value>
    </property>


    <!-- Minio properties -->
    <property>
        <name>fs.s3a.connection.ssl.enabled</name>
        <value>false</value>
    </property>

    <property>
        <name>fs.s3a.endpoint</name>
        <value>http://minio:9000</value>
    </property>

    <property>
        <name>fs.s3a.access.key</name>
        <value>minio</value>
    </property>

    <property>
        <name>fs.s3a.secret.key</name>
        <value>minio123</value>
    </property>

    <property>
        <name>fs.s3a.path.style.access</name>
        <value>true</value>
    </property>

    <property>
        <name>fs.s3a.impl</name>
        <value>org.apache.hadoop.fs.s3a.S3AFileSystem</value>
    </property>

</configuration>
XML
}

run_migrations(){
  if /opt/hive-metastore/bin/schematool -dbType "$DATABASE_TYPE" -validate | grep 'Done with metastore validation' | grep '[SUCCESS]'; then
    echo 'Database OK'
    return 0
  else
    # TODO: how to apply new version migrations or repair validation issues
    /opt/hive-metastore/bin/schematool --verbose -dbType "$DATABASE_TYPE" -initSchema
  fi
}

# configure & run schematool
generate_hive_site_config /opt/hadoop/etc/hadoop/hive-site.xml
run_migrations

# configure & start metastore (in foreground)
generate_metastore_site_config /opt/hive-metastore/conf/metastore-site.xml
generate_core_site_config /opt/hadoop/etc/hadoop/core-site.xml
/opt/hive-metastore/bin/start-metastore
