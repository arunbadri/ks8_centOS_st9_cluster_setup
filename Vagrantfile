
require "yaml"
settings = YAML.load_file "settings.yaml"

IP_SECTIONS = settings["network"]["control_ip"].match(/^([0-9.]+\.)([^.]+)$/)
# First 3 octets including the trailing dot:
IP_NW = IP_SECTIONS.captures[0]
# Last octet excluding all dots:
IP_START = Integer(IP_SECTIONS.captures[1])
NUM_WORKER_NODES = settings["nodes"]["workers"]["count"]
NUM_MASTER_NODES = settings["nodes"]["control"]["count"]
HA_PROXY_IP = settings["network"]["haproxy_ip"] 
HA_PROXY_PORT = settings["nodes"]["haproxy"]["port"]
NFS_SERVER_IP = settings["network"]["nfsserver_ip"]  


Vagrant.configure("2") do |config|
  #config.vbguest.auto_update = false if Vagrant.has_plugin?('vagrant-vbguest')
  #config.vm.synced_folder ".", "/vagrant", type: "rsync", rsync__exclude: ".git/", rsync__args: ["--verbose", "--rsync-path='sudo rsync'", "--archive", "--delete", "-z"]
  config.vm.synced_folder ".", "/vagrant", type: "rsync", rsync__exclude: [".git/", "scripts/", "Vagrantfile", "ha_proxy/"]
  config.vm.provision "shell", env: { "IP_NW" => IP_NW, "IP_START" => IP_START, "NUM_WORKER_NODES" => NUM_WORKER_NODES, "NUM_MASTER_NODES" => NUM_MASTER_NODES, "HA_PROXY_IP" => HA_PROXY_IP, "NFS_SERVER_IP" => NFS_SERVER_IP }, inline: <<-SHELL
      sudo yum update -y
      #echo "$IP_NW$((IP_START)) master-node01" >> /etc/hosts
      #if [ ${NUM_MASTER_NODES} -gt 1 ]
      #  then
        for j in `seq 1 ${NUM_MASTER_NODES}`; do
          echo "$IP_NW$((IP_START+10+j)) master-node0${j}" >> /etc/hosts
        done
      #fi
      for i in `seq 1 ${NUM_WORKER_NODES}`; do
        echo "$IP_NW$((IP_START+i)) worker-node0${i}" >> /etc/hosts
      done

      ## NFS server
      echo "$NFS_SERVER_IP nfs-server" >> /etc/hosts

      ## ha-proxy server
      echo "$HA_PROXY_IP haproxy-node" >> /etc/hosts
SHELL

  config.vm.box = settings["software"]["box"]

  #config.vm.box_version = settings["software"]["box_version"] 
  config.vm.box_check_update = true

  config.vm.define "haproxy" do |haproxy|
    haproxy.vm.hostname = "haproxy-node"
    haproxy.vm.network :forwarded_port, guest: 6443, host: 6443
    haproxy.vm.network :forwarded_port, guest: 8080, host: 8080
    #master.vm.network "private_network", ip: settings["network"]["control_ip"]
    haproxy.vm.network "private_network", ip: HA_PROXY_IP
    if settings["shared_folders"]
      settings["shared_folders"].each do |shared_folder|
        haproxy.vm.synced_folder shared_folder["host_path"], shared_folder["vm_path"]
      end
    end
    haproxy.vm.provider "virtualbox" do |vb|
        vb.name = settings["nodes"]["haproxy"]["name"]
        vb.cpus = settings["nodes"]["haproxy"]["cpu"]
        vb.memory = settings["nodes"]["haproxy"]["memory"]
        if settings["cluster_name"] and settings["cluster_name"] != ""
          vb.customize ["modifyvm", :id, "--groups", ("/" + settings["cluster_name"])]
        end
    end
    haproxy.vm.provision "shell",
      env: {
        "CALICO_VERSION" => settings["software"]["calico"],
        #"CONTROL_IP" => settings["network"]["control_ip"],
        "CONTROL_IP" => HA_PROXY_IP,
        "POD_CIDR" => settings["network"]["pod_cidr"],
        "SERVICE_CIDR" => settings["network"]["service_cidr"],
        "HA_PROXY_PORT" => settings["nodes"]["haproxy"]["port"],
        "NUMBER_OF_MASTER_NODE" => NUM_MASTER_NODES,
        "IP_NW" => IP_NW,
        "IP_START" =>IP_START

      },
      path: "scripts/haproxy-setup.sh"
      #path: "scripts/haproxy-setup.sh", run: 'always'
    haproxy.vm.provision "shell",path: "scripts/bootstrap_nfs.sh"
    
  end


  config.vm.define "master01" do |master|
    master.vm.hostname = "master-node01"
    #master.vm.network "private_network", ip: settings["network"]["control_ip"]
    master.vm.network "private_network", ip: IP_NW + "#{IP_START + 10 +1}"
    if settings["shared_folders"]
      settings["shared_folders"].each do |shared_folder|
        master.vm.synced_folder shared_folder["host_path"], shared_folder["vm_path"]
      end
    end
    master.vm.provider "virtualbox" do |vb|
        vb.name = settings["nodes"]["control"]["name"]+"01"
        vb.cpus = settings["nodes"]["control"]["cpu"]
        vb.memory = settings["nodes"]["control"]["memory"]
        if settings["cluster_name"] and settings["cluster_name"] != ""
          vb.customize ["modifyvm", :id, "--groups", ("/" + settings["cluster_name"])]
        end
    end
    master.vm.provision "shell", path: "scripts/test_sync.sh"
    master.vm.provision "shell",
      env: {
        "DNS_SERVERS" => settings["network"]["dns_servers"].join(" "),
        "ENVIRONMENT" => settings["environment"],
        "KUBERNETES_VERSION" => settings["software"]["kubernetes"],
        "OS" => settings["software"]["os"]
      },
      path: "scripts/common.sh"
      #path: "scripts/common.sh", run: 'always'
      master.vm.provision "shell",
      env: {
        "CALICO_VERSION" => settings["software"]["calico"],
        #"CONTROL_IP" => settings["network"]["haproxy_ip"],
        "CONTROL_IP" => IP_NW + "#{IP_START + 10 +1}",
        "POD_CIDR" => settings["network"]["pod_cidr"],
        "SERVICE_CIDR" => settings["network"]["service_cidr"],
        "HA_PROXY_IP" => HA_PROXY_IP,
        "HA_PROXY_PORT" => HA_PROXY_PORT
      },
      path: "scripts/master.sh"
      #path: "scripts/master.sh", run: 'always'

    ## Sync back master configs to host to use for woker. For this install vagrant plugin -  [vagrant plugin install vagrant-rsync-back]
    master.trigger.after :up, :provision  do |trigger|
    trigger.run = {inline: "scripts/rsync_back.sh master01"}
    end
    
  end
  
  #system("
    #if [ #{ARGV[0]} = 'up' ]; then
     #   echo 'You are doing vagrant up and can execute your script'
     #   ./scripts/rsync_back.sh
    #fi
#")


  if NUM_MASTER_NODES.>(1)
    (2..NUM_MASTER_NODES).each do |j|
      config.vm.define "master0#{j}" do |masterext|
        masterext.vm.hostname = "master-node0#{j}"
        masterext.vm.network "private_network", ip: IP_NW + "#{IP_START + 10 +j}"
        if settings["shared_folders"]
          settings["shared_folders"].each do |shared_folder|
            masterext.vm.synced_folder shared_folder["host_path"], shared_folder["vm_path"]
          end
        end
        masterext.vm.provider "virtualbox" do |vb|
            vb.name = settings["nodes"]["control"]["name"]+"0#{j}"
            vb.cpus = settings["nodes"]["control"]["cpu"]
            vb.memory = settings["nodes"]["control"]["memory"]
            if settings["cluster_name"] and settings["cluster_name"] != ""
              vb.customize ["modifyvm", :id, "--groups", ("/" + settings["cluster_name"])]
            end
        end
        masterext.vm.provision "shell", path: "scripts/test_sync.sh"
        masterext.vm.provision "shell",
          env: {
            "DNS_SERVERS" => settings["network"]["dns_servers"].join(" "),
            "ENVIRONMENT" => settings["environment"],
            "KUBERNETES_VERSION" => settings["software"]["kubernetes"],
            "OS" => settings["software"]["os"]
          },
          path: "scripts/common.sh"
           #path: "scripts/common.sh", run: 'always'
          masterext.vm.provision "shell",
          env: {
            "CALICO_VERSION" => settings["software"]["calico"],
            "CONTROL_IP" => settings["network"]["haproxy_ip"],
            #"CONTROL_IP" => IP_NW + "#{IP_START + 10 +1}",
            "POD_CIDR" => settings["network"]["pod_cidr"],
            "SERVICE_CIDR" => settings["network"]["service_cidr"]
          },
          path: "scripts/master_scale.sh"
          #path: "scripts/master_scale.sh", run: 'always'
    
         ## Sync back master configs to host to use for woker. For this install vagrant plugin -  [vagrant plugin install vagrant-rsync-back]
        #masterext.trigger.after :up, :provision  do |trigger|
        #trigger.run = {inline: "scripts/rsync_back.sh"}
        #end
              
      end
    end
  end






  (1..NUM_WORKER_NODES).each do |i|

    config.vm.define "node0#{i}" do |node|
      node.vm.hostname = "worker-node0#{i}"
      node.vm.network "private_network", ip: IP_NW + "#{IP_START + i}"
      if settings["shared_folders"]
        settings["shared_folders"].each do |shared_folder|
          node.vm.synced_folder shared_folder["host_path"], shared_folder["vm_path"]
        end
      end
      node.vm.provider "virtualbox" do |vb|
          vb.name = settings["nodes"]["workers"]["name"]+"0#{i}"
          vb.cpus = settings["nodes"]["workers"]["cpu"]
          vb.memory = settings["nodes"]["workers"]["memory"]
          if settings["cluster_name"] and settings["cluster_name"] != ""
            vb.customize ["modifyvm", :id, "--groups", ("/" + settings["cluster_name"])]
          end
      end
      node.vm.provision "shell",
        env: {
          "DNS_SERVERS" => settings["network"]["dns_servers"].join(" "),
          "ENVIRONMENT" => settings["environment"],
          "KUBERNETES_VERSION" => settings["software"]["kubernetes"],
          "OS" => settings["software"]["os"]
        },
        path: "scripts/common.sh"
        #path: "scripts/common.sh", run: 'always'
      node.vm.provision "shell", path: "scripts/node.sh"
      #node.vm.provision "shell", path: "scripts/node.sh", run: 'always'

      # Only install the dashboard after provisioning the last worker (and when enabled).
      if i == NUM_WORKER_NODES and settings["software"]["dashboard"] and settings["software"]["dashboard"] != ""
        node.vm.provision "shell", path: "scripts/dashboard.sh"
        #node.vm.provision "shell", path: "scripts/dashboard.sh", run: 'always'
        node.trigger.after :up, :provision  do |trigger_restart_dashboard|
          trigger_restart_dashboard.run = {
            inline: "scripts/restart_dashboard.sh"
          }
        end
        node.trigger.after :up, :provision do |trigger_sync_back|
          trigger_sync_back.run = {
            inline: "scripts/rsync_back.sh node0#{i}"
          }
        end

      end
       ## Sync back master configs to host to use for woker. For this install vagrant plugin -  [vagrant plugin install vagrant-rsync-back]
      #node.trigger.after :up, :provision  do |trigger|
      #trigger.run = {inline: "scripts/rsync_back.sh"}
      #end
    end

  end

  

end 
