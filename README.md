

##### **NGINX Gateway**

The NGINX Gateway (version 1.9.2 with stream module) is a small container service used to provision TCP and HTTP[S] service from kubernetes (tested on version 0.18.2). Essetially we're not running in proper cloud provider but needed a dynamic means of provisioning external load balanced / exposed services. The data, i.e. services and minions is consumed the etcd cluster kubernetes is running via confd (note: confd is purely being used as a trigger to pull down the data and push into json arrays of services: [] and minions: [], the reason being that templating in go is hideous.

    [template]
    src   = "nginx.conf.tmpl"
    dest  = "/etc/nginx/config.json"
    keys  = [
      "/registry/services/specs/",
      "/registry/minions",
    ]
    owner = "root"
    mode  = "0444"

    reload_cmd = "/usr/sbin/nginx -s reload"
    check_cmd  = "/bin/nginx_check {{ .src }}"

Once the data is in the config file: /bin/nginx_check is used to generate the nginx config, with in ruby erb. At the moment the container is pushed out via fleet and mapped to the docker host network (--net=host) so we don't have to preconfigure ports.

##### **Services**

The load balancer config is store in the annontation of the service descriptor. Note, due to the fact that kubernetes wont allow complex types in annotation, i.e. will only support simple key values, I encode the content as a yaml string.

    apiVersion: v1beta3
    kind: Service
    metadata:
      labels:
        name: gitlab-redis
        role: service
      name: gitlab-redis
      annotations:
        loadbalancer: |
          6379:
            # port: PORT  
            type: tcp  
    spec:
      portalIP: 10.101.100.100
      ports:
        - port: 6379
          targetPort: 6379
      selector:
        name: gitlab-redis

By default services use 'port' from the spec as the externally exposed spec, though this can be override using 'port' in the loadbalacer section. For websites

    apiVersion: v1beta3
    kind: Service
    metadata:
      labels:
        name: gitlab-web
      name: gitlab-web
      annotations:
        loadbalancer: |
          80:
            type: http
            vhost: gitlab.example.com
            redirect https://gitlab.example.com
          443:
            type: http
            vhost: gitlab.example.com
            paths:
              - path: /
                backend: 80_admin
            ssl:
              key: <filename>
              cert: <filename>

Note: at the moment the virtualhost on the same port are not consolidated, i.e say you have site X and you have Y backends which you wish to serve on different locations | url's; so / goes to default, /admin goes to backend 1 etc etc. At the moment, i'm not preprocessing the vhosts to perform this, a hash of vhost:port is maintained to ensure you dont try and add the same vhost on the same port.

##### **Flannel & Service Ports**

By passing the -e FLANNEL_ENABLED=true flag into the container, the config generated assumed the docker host it's running on is a member or at the very least mapped into the flannel network and will thus use the portalIP / clusterIP to access the services. If the flag is not enabled we assume the service is being exposed via the NodePort or PublicIPs and use the minion ip addresses at the upstream backends in nginx.

##### **Testing Config**

A example config.json has been placed into the examples/ directory, performing a: 'make test' will generate the config for you. If you wanna test against a different service, there's a bin/nginx_json helper script which will read a kubernetes service file and generate the json for you, which you can copy and paste into the config.json for example

##### **Environment Variables**

  - PROTO_PROTOCOL: enable the nginx proto_protocol (haproxy proxy protocol) - (http://nginx.org/en/docs/http/ngx_http_realip_module.html) for pull the client ip from tcp extension
  - PROTO_PROTOCOL_SUBNET: the subnet of the upstream tcp proxy
  - NGINX_FAIL_TIMEOUT: the timeout used for backend server, note, this applied when your use NodePort, it's ignored if your using the flannel address  
  - NGINX_LOGS: enable the nginx web access logs
  - FLANNEL_ENABLED: enable flannel usage - i.e. the host it's running on is running the kube-proxy and flannel so we can use the kubernetes service proxy
  
