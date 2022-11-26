#!/bin/bash

# Creates new postgres database and imports NHD data
# Usage: ./import.sh dbname datadir [schema]
#   dbname: database name
#   datadir: directory containing NHD data
#   schema: database schema name (default: public)

# see also:
#   https://github.com/NelsonMinar/vector-river-map/blob/master/dataprep/importNhd.sh
#   https://gist.github.com/mojodna/b1f169b33db907f2b8dd

set -eu

dbname=$1
datadir=$2
schema=${3-public}
log=import.log

echo "Importing data from directory \"${datadir}\" to database \"${dbname}\" with schema \"${schema}\""

fail=0; createdb ${dbname} || fail=1 && true
if [[ "$fail" -ne 0 ]]; then
  echo "You need to 'dropdb ${dbname}' for this script to run"
  exit 1
fi
psql -q -d ${dbname} -c 'create extension postgis' > $log 2>&1
psql -q -d ${dbname} -c 'create extension postgis_topology' >> $log 2>&1

if [ "$schema" != "public" ]; then
  echo "Creating schema ${schema}"
  psql -d ${dbname} -c "create schema \"${schema}\"" >> $log 2>&1
fi


# import flowlines
flowlines="${datadir}/NHDPlus??/NHDPlus*/NHDSnapshot/Hydrography/*lowline.shp"
echo ${flowlines}
if [[ ! -z "${flowlines}" ]]; then
  set -- $flowlines
  echo "Creating table ${schema}.flowline"
  (shp2pgsql -p -D -t 2d -s 4269 -W LATIN1 "$1" "$schema".flowline | psql -d $dbname) >> $log 2>&1

  for flowline in $flowlines; do
      echo "Importing ${flowline} to ${schema}.flowline"
      (shp2pgsql -a -D -t 2d -s 4269 -W LATIN1 "$flowline" "$schema".flowline | psql -d $dbname -q) >> $log 2>&1
  done
else
  echo "No flowline files found"
fi


# import waterbodies
waterbodies="${datadir}/NHDPlus??/NHDPlus*/NHDSnapshot/Hydrography/*aterbody.shp"
if [[ ! -z "${waterbodies}" ]]; then
  set -- $waterbodies
  echo "Creating table ${schema}.waterbody"
  (shp2pgsql -p -D -t 2d -s 4269 -W LATIN1 "$1" "$schema".waterbody | psql -d $dbname) >> $log 2>&1

  for waterbody in $waterbodies; do
      echo "Importing ${waterbody} to ${schema}.waterbody"
      (shp2pgsql -a -D -t 2d -s 4269 -W LATIN1 "$waterbody" "$schema".waterbody | psql -d $dbname -q) >> $log 2>&1
  done
else
  echo "No waterbody files found"
fi


# import vaas
vaas="$datadir/NHDPlus??/NHDPlus*/NHDPlusAttributes/PlusFlowlineVAA.dbf"

if [[ ! -z "${vaas}" ]]; then
  set -- $vaas
  echo "Creating table $1"
  (pgdbf -D -s LATIN1 "$1" | psql -d $dbname) >> $log 2>&1
  psql -d $dbname -c "TRUNCATE TABLE public.plusflowlinevaa;" >> $log 2>&1

  for vaa in $vaas; do
      echo "Importing ${vaa} to public.plusflowlinevaa"
      (pgdbf -CD -s LATIN1 "$vaa" | psql -d $dbname -q) >> $log 2>&1
  done

  # move vaa table to schema.vaa
  # b/c pgdbf does not allow setting schema/table name
  echo "Copying value added attributes from public.plusflowlinevaa to ${schema}.vaa"
  psql -d $dbname -c "CREATE TABLE \"${schema}\".vaa AS (SELECT * FROM public.plusflowlinevaa)" >> $log 2>&1
  psql -d $dbname -c "DROP TABLE public.plusflowlinevaa" >> $log 2>&1
else
  echo "No VAA files found"
fi


# import catchments
catchments="$datadir/NHDPlus??/NHDPlus*/NHDPlusCatchment/Catchment.shp"

if [[ ! -z "${catchments}" ]]; then
  set -- $catchments
  echo "Creating table ${schema}.catchment"
  (shp2pgsql -p -D -t 2d -s 4269 -W LATIN1 "$1" "$schema".catchment | psql -d $dbname) >> $log 2>&1

  for catchment in $catchments; do
      echo "Importing ${catchment} to ${schema}.catchment"
      (shp2pgsql -a -D -t 2d -s 4269 -W LATIN1 "$catchment" "$schema".catchment | psql -d $dbname -q) >> $log 2>&1
  done
else
  echo "No catchment files found"
fi


# import watershed boundary datasets
wbds="$datadir/NHDPlus??/NHDPlus*/WBDSnapshot/WBD/WBD_Subwatershed.shp"

if [[ ! -z "${wbds}" ]]; then
  set -- $wbds
  echo "Creating table ${schema}.wbd"
  (shp2pgsql -p -D -t 2d -s 4269 -W LATIN1 "$1" "$schema".wbd | psql -d $dbname -q) >> $log 2>&1

  for wbd in $wbds; do
      echo "Importing ${wbd} to ${schema}.wbd"
      (shp2pgsql -a -D -t 2d -s 4269 -W LATIN1 "$wbd" "$schema".wbd | psql -d $dbname -q) >> $log 2>&1
  done
else
  echo "No WBD files found"
fi

