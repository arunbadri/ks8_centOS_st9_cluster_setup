# ks8_centOS_st9_cluster_setup
Setting up ks8 cluster on centOS 9 stream using Vagrant

1. Clone the branch
2. Install vagrant plugin :

   vagrant plugin install vagrant-rsync-back

   This is required as CentoS 9 Stream (guestVM) and MacOS(Host), the rysnc is unidirectional. Where the files are only sync betwenn Host -> guestVM

3. Run the vagrant to install Ks8 cluster of 3 on CentOS9 Stream
   vagrant run
