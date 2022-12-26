#!/bin/bash
sudo apt update && sudo apt upgrade -y
sudo apt autoremove --purge
sudo apt autoclean
curl -fsSL https://deb.nodesource.com/setup_16.x | sudo -E bash -
sudo useradd -m app -p PASSWORD
sudo groupadd app
sudo adduser app app
sudo apt-get install wget
sudo apt-get install nodejs
sudo npm install -g npm@latest
sudo npm install -g pm2@latest
sudo apt install net-tools -y
sudo apt install collectd -y
sudo apt install awscli -y
#installing codedeploy

sudo apt update
sudo apt install ruby-full -y
sudo wget https://aws-codedeploy-us-west-2.s3.us-west-2.amazonaws.com/latest/install
cd /home/ubuntu
sudo chmod +x ./install
sudo ./install auto > /tmp/logfile
sudo systemctl start codedeploy-agent
sudo systemctl enable codedeploy-agent
#installing cloudwatch-agent

cd /home/ubuntu
sudo wget https://s3.us-west-2.amazonaws.com/amazoncloudwatch-agent-us-west-2/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
sudo dpkg -i -E ./amazon-cloudwatch-agent.deb
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c ssm:AmazonCloudWatch-rachit -s
sudo systemctl start amazon-cloudwatch-agent.service
sudo systemctl enable amazon-cloudwatch-agent.service
sudo systemctl status amazon-cloudwatch-agent.service

cd /home/app
