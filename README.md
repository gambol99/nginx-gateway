

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

##### **Flannel & Service Ports** 
 
By passing the -e FLANNEL_ENABED=true flag into the container, the config generated assumed the docker host it's running on is a member or at the very least mapped into the flannel network and will thus use the portalIP / clusterIP to access the services. If the flag is not enabled we assume the service is being exposed via the NodePort or PublicIPs and use the minion ip addresses at the upstream backends in nginx.