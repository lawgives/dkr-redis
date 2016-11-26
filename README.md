# dkr-redis
Redis (with Sentinel and Slave mode)

## Design Notes

Since this image is intended to be useable as a Redis cluster member, the configuration
file must writeable in order to persist state. As a result, during container bootup, we
want to copy the configuration file into the data volume if one does not exist.

By copying the conf only if it does not exist, we can mount the data volume on a
persistent disk and save state (such as whether the node is a master or a slave).

This also means that we do not need a seperate slave configuration. We can bring
up an independent master, then set it as a slave and get monitored by sentinel.

## Docker

### Starting default (independent master)

```
docker run legalio/redis:3.2.5
```

### Starting Sentinel

```
docker run -e SENTINEL=1 legalio/redis:3.2.5
```

You will have to pass in `REDIS_SENTINEL_SERVICE_HOST` and `REDIS_SENTINEL_SERVICE_PORT`. On
Kubernetes, with a redis-sentinel service, these env variabiles will be populated. (We can
reuse the same sentinel cluster to monitor multiple clusters, so it is reasonable to bake
in the name of the service)

Other configurations:

  * `REDIS_GROUP` seed name of redis group to monitor (default: `redis`)
  * `REDIS_QUORUM` quorum for seed group (default: `2`)
  * `REDIS_DOWN_AFTER_MS` sentinel `down-after-milliseconds` setting (default: `60000`)
  * `REDIS_FAILOVER_TIMEOUT` sentinel `failover-timeout` setting (default: `180000`)
  * `REDIS_PARALLEL_SYNCS` sentinel `parllel-syncs` setting (default: `1`)
  
*IMPORTANT NOTE*: Sentinel will *not* propogate configuration. These settings must be
kept in sync by a different mechanism. Consider using StatefulSet for Sentinel and
develop a mechanism to update all sentinels in the stateful set.

## Bootstrapping on Kubernetes

The examples given on Kubernetes uses a bootstrap pod that runs a sentinel as
a sidecar to the first Redis. From there, replicas of sentinel are created,
then a replica set of redis pods. Those will connect to sentinel and start
syncing. Once the syncing is done, delete the bootstrap pod.

Syncing is accomplished by bringing up additional independent masters, then
setting them as `slave-of` the bootstrap. Once all the permanent members and
sentinel has been created, you can shut down bootstrap server. Sentinel will
choose a new master and update the cluster with the new configuration. If the
data volume is backed by a persistent disk, then that will get persisted.

## See Also

  1. https://redis.io/topics/sentinel
  2. https://github.com/kubernetes/kubernetes/tree/master/examples/storage/redis
  3. https://clusterhq.com/2016/02/11/kubernetes-redis-cluster/
