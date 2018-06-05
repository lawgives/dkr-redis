#!/bin/bash
set -e

# Based on: https://github.com/kubernetes/kubernetes/blob/master/examples/storage/redis/image/run.sh
# Based on: https://github.com/docker-library/redis/blob/54ec6b70a3afd6ec62a6549621c5ca1053ece7f5/3.2/alpine/docker-entrypoint.sh

function lookup_announce_ip() {
    #nameserver=$(cat /etc/resolv.conf | awk '/^nameserver/ { print $2 }')
    # Do not add a nameserver, otherwise we get multiple addresses
    namespace=$(cat /etc/resolv.conf | awk '/^search/ { print $2 }')
    nslookup $(hostname).${namespace} 2> /dev/null | awk '/^Address.*svc/ { print $3 }'
}

function launch_redis() {
    echo "Launching redis"
    redis_conf="/data/redis.conf"

    if [[  -e ${redis_conf} ]]; then
        echo "Existing redis.conf found, starting up redis"
    else
        echo "No existing redis.conf found, starting up redis with defaults from /etc/redis/redis.conf"
        cp /etc/redis/redis.conf ${redis_conf}
        chown -R redis:redis /data
    fi

    slave_announce_ip=""
    if [[ -n ${LOOKUP_ANNOUNCE_IP} ]]; then
        echo "Looking up service ip using hostname $(hostname)"
        announce_ip=$(lookup_announce_ip)
        echo "Setting announce IP to ${announce_ip}"
        slave_announce_ip="--slave-announce-ip ${announce_ip}"
    elif [[ -n ${REDIS_SLAVE_ANNOUNCE_IP_VAR} ]]; then
        echo "Setting slave-announce-ip to ${!REDIS_SLAVE_ANNOUNCE_IP_VAR}"
        slave_announce_ip="--slave-announce-ip ${!REDIS_SLAVE_ANNOUNCE_IP_VAR}"
    fi

    server_args="/data/redis.conf --protected-mode no ${slave_announce_ip} ${REDIS_SERVER_ARGS}"
    echo "Invoking redis-server with: ${server_args}"

    exec su-exec redis redis-server ${server_args}
}

function launch_sentinel {
    echo "Launching redis sentinel"
    while true; do
        sentinel_conf=/data/sentinel.conf
        redis_group=${REDIS_GROUP:-redis}
        quorum=${REDIS_QUORUM:-2}

        # Try to discover redis sentinal via Kubernetes service
        master=""

        if [[ -n ${REDIS_SENTINEL_SERVICE_HOST} && -n ${REDIS_SENTINEL_SERVICE_PORT} ]]; then
            # Query any existing redis-sentinels and ask for a master
            master=$(redis-cli -h ${REDIS_SENTINEL_SERVICE_HOST} -p ${REDIS_SENTINEL_SERVICE_PORT} --csv SENTINEL get-master-addr-by-name ${redis_group} | tr ',' ' ' | cut -d' ' -f1)
            echo "Found master from redis-sentinel: ${master}"
        fi

        if [[ -n ${master} ]]; then
            master="${master//\"}"
    	elif [[ -n ${REDIS_MASTER_HOST_VAR} ]]; then
	    # If we still cannot find the master, see if
	    # we have a REDIS_MASTER_HOST_VAR set. Take the
	    # value from that.
	    master=${!REDIS_MASTER_HOST_VAR}
    	fi

	# Fall back to using hostname
	if [[ -z ${master} ]]; then
            # If it cannot be found, use the current pod ip
            # This allows the bootstrap pod to run sentinel as
            # a sidecar container
            master=$(hostname -i)
            echo "Defaulting master to current pod: ${master}"
        fi

        # Check that server is up
        redis-cli -h ${master} INFO

        # IF we can find the master, get out of here and
        # run sentinel
        if [[ "$?" == "0" ]]; then
            break
        fi

        echo "Connecting to master (${master}) failed.  Waiting..."
        sleep 10
    done

    echo ""
    echo ""
    echo "====================="
    echo "Starting up sentinel with master group: ${redis_group} (${master})"

    # monitor setting needs to bind master ip with the redis group
    echo "sentinel monitor ${redis_group} ${master} 6379 ${quorum}" > ${sentinel_conf}

    # sentinel settings need the name of the master
    down_after_ms=${REDIS_DOWN_AFTER_MS:-60000}
    failover_timeout=${REDIS_FAILOVER_TIMEOUT:-180000}
    parallel_syncs=${REDIS_PARALLEL_SYNC:-1}

    echo "sentinel down-after-milliseconds ${redis_group} ${down_after_ms}" >> ${sentinel_conf}
    echo "sentinel failover-timeout ${redis_group} ${failover_timeout}" >> ${sentinel_conf}
    echo "sentinel parallel-syncs ${redis_group} ${parallel_syncs}" >> ${sentinel_conf}
    echo "dir /data" >> ${sentinel_conf}
    echo "bind 0.0.0.0" >> ${sentinel_conf}

    if [[ -n "${LOOKUP_ANNOUNCE_IP}" ]]; then
        echo "Looking up service ip using hostname $(hostname)"
        announce_ip=$(lookup_announce_ip)
        echo "Setting announce IP to ${announce_ip}"
        echo "sentinel announce-ip ${announce_ip}" >> ${sentinel_conf}
    elif [[ -n "${REDIS_ANNOUNCE_IP_VAR}" ]]; then
        echo "Using REDIS_ANNOUNCE_IP_VAR ${REDIS_ANNOUNCE_IP_VAR}"
        echo "Setting sentinel announce-ip to ${!REDIS_ANNOUNCE_IP_VAR}"
        echo "sentinel announce-ip ${!REDIS_ANNOUNCE_IP_VAR}" >> ${sentinel_conf}
    else
        echo "Using $(hostname -i) for announce ip"
    fi

    echo ""
    echo "Final config:"
    echo "========="
    echo ""
    cat ${sentinel_conf}

    # Redis requires the configuration to be writeable
    chown -R redis:redis /data

    exec su-exec redis /usr/local/bin/redis-sentinel ${sentinel_conf}
}

if [[ -n "${SENTINEL}" ]]; then
    launch_sentinel
    exit 0
fi

launch_redis
