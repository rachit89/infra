acker {
  required_plugins {
    amazon = {
      version = ">= 1.1.6"
      source  = "github.com/hashicorp/amazon"
    }
  }
}


source "amazon-ebs" "rachit-node-ami-5" {
  ami_name      = "rachit-node-ami-5"
  instance_type = "t3a.small"
  region        = "us-west-2"
  source_ami = "ami-0530ca8899fac469f"
  ssh_username = "ubuntu"
  iam_instance_profile = "rachit-codedeploy"
}

build {
  sources = [
    "source.amazon-ebs.rachit-node-ami-5"
  ]
  provisioner "shell" {
  script       = "./script.sh"
}
}
