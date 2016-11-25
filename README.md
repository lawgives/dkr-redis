# dkr-redis
Redis (with Sentinel and Slave mode)

## Docker

### Starting Master

```
docker run legalio/redis:3.2.5 redis-server /etc/redis/master.conf
```

### Starting Sentinel

```
docker run legalio/redis:3.2.5 redis-sentinel
```

You will have to pass in `REDIS_SENTINEL_SERVICE_HOST` and `REDIS_SENTINEL_SERVICE_PORT`. On
Kubernetes, with a redis-sentinel service, these env variabiles will be populated.

### Starting Slave

This is not supported in this image. For Kubernetes, this is not necessary.

## Bootstrapping on Kubernetes

The examples given on Kubernetes uses a bootstrap pod that runs a sentinel as
a sidecar to the first Redis. From there, replicas of sentinel are created,
then a replica set of redis pods. Those will connect to sentinel and start
syncing. Once the syncing is done, delete the bootstrap pod.

## See Also

  1. https://github.com/kubernetes/kubernetes/tree/master/examples/storage/redis
  2. https://clusterhq.com/2016/02/11/kubernetes-redis-cluster/
