For running the above Terraform code Following are the prerequisites : Which I have defined under the locals section in main.tf

Environment = "dev" 
Terraform = "true" 
ami = "ami-0530ca8899fac469f" ## Base image of Ubuntu 20.04 
instance_type = "t3a.small" 
key_name = "rachit1" 
Owner = "RACHIT" 
name = "rachit" 
region = "us-west-2" 
image_id = "ami-080beefdfafc6e5c4" ## Custom Image build using Packer 
name_prefix = "rachi" 
host_headers = ["rachitvpn.***************"] ## Domain for VPN Server

Changing the above values according to your needs one can run the above terraform code.
