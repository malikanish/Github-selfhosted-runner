#!/bin/bash
# -------------------------------
# Ubuntu 24.04 User Data for Self-Hosted GitHub Runner
# -------------------------------

# Update system and install dependencies
apt-get update -y
apt-get install -y curl jq unzip git

# -------------------------------
# Install AWS CLI v2
# -------------------------------
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install
aws --version

# -------------------------------
# GitHub repo details
# -------------------------------
GH_OWNER="malikanish"
GH_REPO="Github-selfhosted-runner"
REGION="us-east-1"
SSM_PARAM_NAME="/github/selfhosted/pat"

# Fetch GitHub PAT from SSM Parameter Store
GH_PAT=$(aws ssm get-parameter --name "$SSM_PARAM_NAME" --with-decryption --region $REGION --query "Parameter.Value" --output text)

# -------------------------------
# Download and setup latest GitHub Runner
# -------------------------------
RUNNER_VERSION=$(curl -s https://api.github.com/repos/actions/runner/releases/latest | jq -r .tag_name)
RUNNER_DIR="/home/ubuntu/actions-runner"

rm -rf $RUNNER_DIR
mkdir -p $RUNNER_DIR
chown -R ubuntu:ubuntu $RUNNER_DIR
cd $RUNNER_DIR || exit 1

# Download latest runner tar as ubuntu
sudo -u ubuntu curl -o actions-runner.tar.gz -L https://github.com/actions/runner/releases/download/${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION:1}.tar.gz
sudo -u ubuntu tar xzf actions-runner.tar.gz --strip-components=1

# Make all scripts executable
chmod +x *.sh
chown -R ubuntu:ubuntu $RUNNER_DIR

# -------------------------------
# Register runner with GitHub
# -------------------------------
RUNNER_TOKEN=$(curl -s -X POST -H "Authorization: token ${GH_PAT}" \
  https://api.github.com/repos/${GH_OWNER}/${GH_REPO}/actions/runners/registration-token | jq -r .token)

# Configure runner
sudo -u ubuntu ./config.sh --url https://github.com/${GH_OWNER}/${GH_REPO} --token ${RUNNER_TOKEN} --unattended --labels ec2

# -------------------------------
# Start runner service (as root)
# -------------------------------
sudo ./svc.sh install
sudo ./svc.sh start
sudo ./svc.sh status

# Auto shutdown 2 min after job
# -------------------------------
sudo shutdown -h +2


exit 0