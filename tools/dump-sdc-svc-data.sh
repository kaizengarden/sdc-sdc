#!/bin/bash
#
# Dump data from SDC services to "/var/log/sdc-svc-data/..."
#
# The intention is that this is run at the top of the hour. Then a separate
# cronjob running 'upload-sdc-svc-data.sh' uploads all those to Manta. The
# separation is to separate failure modes. Each script will log and an Amon
# probe will watch for 'fatal error' in those logs.
#
# Uploading to Manta only happens if the 'sdc' application is configured with
# a SDC_MANTA_URL. To avoid endless filling of /var/log/sdc-svc-data, dumps
# older than a week will be removed.
#
# TODO: add other services; ensure not too heavy on them (e.g. full dump of VMs)
#

if [[ -n "$TRACE" ]]; then
    export PS4='[\D{%FT%TZ}] ${BASH_SOURCE}:${LINENO}: ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
    set -o xtrace
fi
set -o errexit
set -o pipefail



#---- globals/config

PATH=/opt/smartdc/sdc/bin:/opt/smartdc/sdc/build/node/bin:/opt/local/bin:/opt/local/sbin:/usr/bin:/usr/sbin

TOP=$(cd $(dirname $0)/../; pwd)
CONFIG=$TOP/etc/config.json
JSON=$TOP/node_modules/.bin/json

DUMPDIR=/var/log/sdc-svc-data



#---- support stuff

function fatal
{
    echo "$0: fatal error: $*"
    exit 1
}

function errexit
{
    [[ $1 -ne 0 ]] || exit 0
    fatal "error exit status $1"
}



#---- mainline

trap 'errexit $?' EXIT

echo ""
echo "--"
START=$(date +%s)
echo "$0 started at $(date -u '+%Y-%m-%dT%H:%M:%S')"

TIMESTAMP=$(date -u "+%s")
mkdir -p /var/log/sdc-svc-data

echo "Purge dumps older than a week."
for path in $(ls $DUMPDIR/*-*-*.json 2>/dev/null)
do
    f=$(basename $path)
    dumptime=$(echo $f | cut -d- -f 3 | cut -d. -f 1)
    # 604800 is a week of seconds
    if [[ $dumptime -lt $(( $START - 604800 )) ]]; then
        echo "Purging more-than-week-old dump file '$path'"
        rm -f $path
    fi
done

echo "Dump IMGAPI images"
sdc-imgapi /images?state=all >$DUMPDIR/imgapi-images-$TIMESTAMP.json

# PII cert, drop customer_metadata and internal_metadat
echo "Dump VMAPI vms"
sdc-vmapi /vms?state=active \
    | $JSON -e 'this.customer_metadata=undefined; this.internal_metadata=undefined;' \
    >$DUMPDIR/vmapi-vms-$TIMESTAMP.json

echo "Dump CNAPI servers"
sdc-cnapi /servers?extras=all >$DUMPDIR/cnapi-servers-$TIMESTAMP.json

# TODO: not sure about dumping all Amon alarms. This endpoint was never intended
# for prod use.
echo "Dump Amon alarms"
sdc-amon /alarms >$DUMPDIR/amon-alarms-$TIMESTAMP.json

echo "Dump NAPI nic_tags, nics, networks, network_pools"
sdc-napi /nic_tags >$DUMPDIR/napi-nic_tags-$TIMESTAMP.json
sdc-napi /nics >$DUMPDIR/napi-nics-$TIMESTAMP.json
sdc-napi /networks >$DUMPDIR/napi-networks-$TIMESTAMP.json
sdc-napi /network_pools >$DUMPDIR/napi-network_pools-$TIMESTAMP.json

echo "Dump SAPI applications, services, instances"
sdc-sapi /applications >$DUMPDIR/sapi-applications-$TIMESTAMP.json
sdc-sapi /services >$DUMPDIR/sapi-services-$TIMESTAMP.json
sdc-sapi /instances >$DUMPDIR/sapi-instances-$TIMESTAMP.json

echo "Dump Workflow workflows, jobs"
sdc-workflow /workflows >$DUMPDIR/workflow-workflows-$TIMESTAMP.json
# TODO: Disabled right now pending discussion on timeouts here in heavy usage.
#sdc-workflow /jobs >$DUMPDIR/workflow-jobs-$TIMESTAMP.json

ls -al $DUMPDIR/*$TIMESTAMP*

END=$(date +%s)
echo "$0 finished at $(date -u '+%Y-%m-%dT%H:%M:%S') ($(($END - $START)) seconds)"