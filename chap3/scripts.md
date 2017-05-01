# ambassador

* docker-machine create -d virtualbox redis-host
* docker-machine create -d virtualbox identidock-host
* eval $(docker-machine env redis-host)
* docker run -d --name real-redis redis:3
* docker run -d --name real-redis-ambassador \
-p 6379:6379
--link real-redis:real-redis
amouat/ambassador
* eval $(docker-machine env identidock-host)
* docker run -d --name redis_ambassador --expose 6379 \
-e REDIS_PORT_6379_TCP=tcp://$(docker-machine ip redis-host):6379 \
amouat/ambassador
* docker run -d --name dnmonster amouat/dnmonster:1.0
* docker run -d --link dnmonster:dnmonster --link redis_ambassador -p 80:9090 amouat/identidock:1.0

* curl $(docker-machine ip identidock-host)


# etcd

* docker-machine create -d virtualbox etcd-1
* docker-machine create -d virtualbox etcd-2
* HOSTA=$(docker-machine ip etcd-1)
* HOSTB=$(docker-machine ip etcd-2)
* eval $(docker-machine env etcd-1)
* docker run -d -p 2379:2379 -p 2380:2380 -p 4001:4001 --name etcd quay.io/coreos/etcd /usr/local/bin/etcd -name etcd-1 -initial-advertise-peer-urls http://${HOSTA}:2380 -listen-peer-urls http://0.0.0.0:2380 -listen-client-urls http://0.0.0.0:2379,http://0.0.0.0:4001 -advertise-client-urls http://${HOSTA}:2379 -initial-cluster-token etcd-cluster-1 -initial-cluster etcd-1=http://${HOSTA}:2380,etcd-2=http://${HOSTB}:2380 -initial-cluster-state new

* eval $(docker-machine env etcd-2)
* docker run -d -p 2379:2379 -p 2380:2380 -p 4001:4001 --name etcd quay.io/coreos/etcd /usr/local/bin/etcd -name etcd-2 -initial-advertise-peer-urls http://${HOSTB}:2380 -listen-peer-urls http://0.0.0.0:2380 -listen-client-urls http://0.0.0.0:2379,http://0.0.0.0:4001 -advertise-client-urls http://${HOSTB}:2379 -initial-cluster-token etcd-cluster-1 -initial-cluster etcd-1=http://${HOSTA}:2380,etcd-2=http://${HOSTB}:2380 -initial-cluster-state new

* curl -s http://$HOSTA:2379/v2/members | jq '.'
* curl -s http://$HOSTB:2379/v2/members | jq '.'

* curl -s http://$HOSTA:2379/v2/keys/service_name -XPUT -d value="service_address" | jq '.'
* curl -s http://$HOSTA:2379/v2/keys/service_name | jq '.'
* curl -s http://$HOSTB:2379/v2/keys/service_name | jq '.'
* docker run binocarlos/etcdctl -C ${HOSTB}:2379 get service_name

# SkyDNS

* curl -XPUT http://${HOSTA}:2379/v2/keys/skydns/config -d value='{"dns_addr":"0.0.0.0:53", "domain":"identidock.local."}' | jq .
* eval $(docker-machine env etcd-1)
* docker run -d -e ETCD_MACHINES="http://${HOSTA}:2379,http://${HOSTB}:2379" --name dns skynetservices/skydns:2.5.2a
* docker run -d -p 6379:6379 --name redis redis:3
* curl -XPUT http://${HOSTA}:2379/v2/keys/skydns/local/identidock/redis -d value='{"host":"'$HOSTB'", "port":6379}' | jq .

* eval $(docker-machine env etcd-1)
* docker run --dns $(docker inspect -f {{.NetworkSettings.IPAddress}} dns) -it redis:3 bash
  * ping redis.identidock.local
  * redis-cli -h redis.identidock.local ping
  * ping redis #=> this returns error
* docker run --dns $(docker inspect -f {{.NetworkSettings.IPAddress}} dns) --dns-search identidock.local -it redis:3 redis-cli -h redis ping

* docker-machine ssh etcd-1
  * echo -e "domain identidock.local \nnameserver " $(docker inspect -f {{.NetworkSettings.IPAddress}} dns) > /etc/resolv.conf
  * cat /etc/resolv.conf
* docker run redis:3 redis-cli -h redis ping

* docker run -d --name dnmonster amouat/dnmonster:1.0
* DNM_IP=$(docker inspect -f {{.NetworkSettings.IPAddress}} dnmonster)
* curl -XPUT http://$HOSTA:2379/v2/keys/skydns/local/identidock/dnmonster -d value='{"host": "'$DNM_IP'", "port":8080}'

* docker exec -it dns sh
  * dig @localhost SRV redis.identidock.local
  * http://www.atmarkit.co.jp/ait/articles/0403/09/news076.html


# Consul

* docker-machine create -d virtualbox consul-1
* docker-machine create -d virtualbox consul-2

* HOSTA=$(docker-machine ip consul-1)
* HOSTB=$(docker-machine ip consul-2)

* eval $(docker-machine env consul-1)
* docker run -d --name consul -h consul-1 \
-p 8300:8300 -p 8301:8301 -p 8301:8301/udp \
-p 8302:8302/udp -p 8400:8400 -p 8500:8500 \
-p 53:8600/udp \
gliderlabs/consul agent -data-dir /data -server \
-client 0.0.0.0 \
-advertise $HOSTA -bootstrap-expect 2
* eval $(docker-machine env consul-2)
* docker run -d --name consul -h consul-2 \
-p 8300:8300 -p 8301:8301 -p 8301:8301/udp \
-p 8302:8302/udp -p 8400:8400 -p 8500:8500 \
-p 53:8600/udp \
gliderlabs/consul agent -data-dir /data -server \
-client 0.0.0.0 \
-advertise $HOSTB -join $HOSTA
* docker exec consul consul members
* curl -XPUT http://$HOSTA:8500/v1/kv/foo -d bar
* curl http://$HOSTA:8500/v1/kv/foo | jq .

* eval $(docker-machine env consul-2)
* docker run -d -p 6379:6379 --name redis redis:3
* curl -XPUT http://$HOSTA:8500/v1/agent/service/register \
-d '{"name": "redis", "address": "'$HOSTB'", "port": 6379}'
* docker run amouat/network-utils dig 



Networking
====

# Overlay

* docker-machine create -d virtualbox overlay-1
* docker-machine create -d virtualbox overlay-2

* HOSTA=$(docker-machine ip overlay-1)
* HOSTB=$(docker-machine ip overlay-2)

* eval $(docker-machine env overlay-1)
* docker run -d --name consul -h overlay-1 \
-p 8300:8300 -p 8301:8301 -p 8301:8301/udp \
-p 8302:8302/udp -p 8400:8400 -p 8500:8500 \
-p 172.17.0.1:53:8600/udp \
gliderlabs/consul agent -data-dir /data -server \
-client 0.0.0.0 \
-advertise $HOSTA -bootstrap-expect 2
* eval $(docker-machine env overlay-2)
* docker run -d --name consul -h overlay-2 \
-p 8300:8300 -p 8301:8301 -p 8301:8301/udp \
-p 8302:8302/udp -p 8400:8400 -p 8500:8500 \
-p 172.17.0.1:53:8600/udp \
gliderlabs/consul agent -data-dir /data -server \
-client 0.0.0.0 \
-advertise $HOSTB -join $HOSTA

* eval $(docker-machine env overlay-1)
* docker exec consul consul members

* eval $(docker-machine env overlay-2)
* docker run -d -p 6379:6379 --name redis redis:3
* curl -XPUT http://$HOSTA:8500/v1/agent/service/register \
-d '{"name": "redis", "address": "'$HOSTB'", "port": 6379}'
* docker run amouat/network-utils dig @172.17.0.1 +short redis.service.consul
  * this returns HOSTB ip in which redis container works

* docker-machine ssh overlay-1
  * sudo vi /var/lib/boot2docker/profile
* eval $(docker-machine env overlay-1)
* docker-machine restart overlay-1
* docker run consul
* docker run redis:3 redis-cli -h redis ping

* docker run -d --name dnmonster amouat/dnmonster:1.0
* DNM_IP=$(docker inspect -f {{.NetworkSettings.IPAddress}} dnmonster)
* curl -XPUT http://$HOSTA:8500/v1/agent/service/register \
-d '{"name": "dnmonster", "address": "'$DNM_IP'", "port": 8080}'
* docker run -d -p 80:9090 amouat/identidock:1.0
* curl $HOSTA

* curl -XPUT http://$HOSTA:8500/v1/agent/service/register \
-d '{"name": "dnmonster", "address": "'$DNM_IP'", "port": 8080, "check": {"http" : "http://'$DNM_IP':8080/monster/foo", "interval": "10s"}}'
* curl -s $HOSTA:8500/v1/health/checks/dnmonster | jq '.[].Status'







 




