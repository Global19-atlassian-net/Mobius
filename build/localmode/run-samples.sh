#!/bin/bash

#
# Copyright (c) Microsoft. All rights reserved.
# Licensed under the MIT license. See LICENSE file in the project root for full license information.
#

export verbose=

for param in "$@"
do
  case "$param" in
    --verbose) export verbose="--verbose"
    ;;
  esac
done

# setup Hadoop and Spark versions
export SPARK_VERSION=2.3.1
export HADOOP_VERSION=2.6
export APACHE_DIST_SERVER=archive.apache.org
echo "[run-samples.sh] SPARK_VERSION=$SPARK_VERSION, HADOOP_VERSION=$HADOOP_VERSION, APACHE_DIST_SERVER=$APACHE_DIST_SERVER"

export FWDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# download runtime dependencies: spark
export TOOLS_DIR="$FWDIR/../tools"
[ ! -d "$TOOLS_DIR" ] && mkdir "$TOOLS_DIR"

export SPARK=spark-$SPARK_VERSION-bin-hadoop$HADOOP_VERSION
export SPARK_HOME="$TOOLS_DIR/$SPARK"
if [ ! -d "$SPARK_HOME" ];
then
  wget "http://$APACHE_DIST_SERVER/dist/spark/spark-$SPARK_VERSION/$SPARK.tgz" -O "$TOOLS_DIR/$SPARK.tgz"
  tar xfz "$TOOLS_DIR/$SPARK.tgz" -C "$TOOLS_DIR"
fi
export PATH="$SPARK_HOME/bin:$PATH"

# update spark verbose mode
if [ ! "$verbose" = "--verbose" ];
then
  # redirect the logs from console (default) to /tmp
  cp "$FWDIR"/spark.conf/*.properties "$SPARK_HOME/conf/"
  sed -i "s/\${env:TEMP}/\/tmp/g" "$SPARK_HOME/conf/log4j.properties"
else
  # remove customized log4j.properties, revert back to out-of-the-box Spark logging to console
  rm -f "$SPARK_HOME"/conf/*.properties
fi

# update sparkclr verbose mode
export SPARKCLRCONF="$FWDIR/../runtime/samples"
export SUFFIX=".original"
if [ ! "$verbose" = "--verbose" ];
then
  for file in `ls "$SPARKCLRCONF"/*.config`
  do
    # backup
    if [ -f "$file$SUFFIX" ];
    then
      cp "$file$SUFFIX" "$file"
    else
      cp "$file" "$file$SUFFIX"
    fi
    sed -i 's/<appender-ref\s*ref="ConsoleAppender"\s*\/>/<\!-- <appender-ref ref="ConsoleAppender" \/> -->/g' "$file"
  done
else
  # restore from original configs
  for file in `ls "$SPARKCLRCONF"/*.config`
  do
    [ -f "$file$SUFFIX" ] && cp "$file$SUFFIX" "$file"
  done
fi


export SPARKCLR_HOME="$FWDIR/../runtime"
# spark-csv package and its depenedency are required for DataFrame operations in Mobius
export SPARKCLR_EXT_PATH="$SPARKCLR_HOME/dependencies"
export SPARKCSV_JAR1PATH="$SPARKCLR_EXT_PATH/spark-csv_2.10-1.4.0.jar"
export SPARKCSV_JAR2PATH="$SPARKCLR_EXT_PATH/commons-csv-1.4.jar"
export SPARKCLR_EXT_JARS="$SPARKCSV_JAR1PATH,$SPARKCSV_JAR2PATH"

# run-samples.sh is in local mode, should not load Hadoop or Yarn cluster config. Disable Hadoop/Yarn conf dir.
export HADOOP_CONF_DIR=
export YARN_CONF_DIR=

export TEMP_DIR=$SPARKCLR_HOME/Temp
[ ! -d "$TEMP_DIR" ] && mkdir "$TEMP_DIR"
export SAMPLES_DIR=$SPARKCLR_HOME/samples

echo "[run-samples.sh] JAVA_HOME=$JAVA_HOME"
echo "[run-samples.sh] SPARK_HOME=$SPARK_HOME"
echo "[run-samples.sh] SPARKCLR_HOME=$SPARKCLR_HOME"
echo "[run-samples.sh] SPARKCLR_EXT_JARS=$SPARKCLR_EXT_JARS"

echo "[run-samples.sh] sparkclr-submit.sh --jars $SPARKCLR_EXT_JARS --conf spark.sql.warehouse.dir=$TEMP_DIR --exe SparkCLRSamples.exe $SAMPLES_DIR spark.local.dir $TEMP_DIR sparkclr.sampledata.loc $SPARKCLR_HOME/data $@"
"$SPARKCLR_HOME/scripts/sparkclr-submit.sh" --jars "$SPARKCLR_EXT_JARS" --conf spark.sql.warehouse.dir="$TEMP_DIR" --exe SparkCLRSamples.exe "$SAMPLES_DIR" spark.local.dir "$TEMP_DIR" sparkclr.sampledata.loc "$SPARKCLR_HOME/data" "$@"

# explicitly export the exitcode as a reminder for future changes
export exitcode=$?
exit $exitcode
