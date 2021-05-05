KEY_NAME="parking-lot-`date +'%N'`"
KEY_PEM="$KEY_NAME.pem"
REPO_NAME=ParkingLotAWS
REPO_URL=https://github.com/yanivNaor92/ParkingLotAWS.git

echo "checking all necessary tools are installed" # todo: improve
if ! command -v jq &> /dev/null; then
    echo "jq could not be found, pleas install it and run the script again"
else
  if ! command -v aws &> /dev/null; then
    echo "aws could not be found, pleas install it, configure your aws account, and run the script again"
  else
    if ! command -v aws &> /dev/null; then
      echo "git could not be found, pleas install it and run the script again"
    fi
  fi
fi

echo "creating a key pair $KEY_PEM"
aws ec2 create-key-pair --key-name $KEY_NAME | jq -r ".KeyMaterial" > $KEY_PEM

# secure the key pair
chmod 400 $KEY_PEM

SEC_GRP="my-sg-`date +'%N'`"

echo "setup security group $SEC_GRP"
aws ec2 create-security-group   \
    --group-name $SEC_GRP       \
    --description "Access the parking lot instances"

# get local ip
LOCAL_IP=$(curl ipinfo.io/ip)
echo "Local IP: $LOCAL_IP"

echo "setup rule allowing SSH access to $LOCAL_IP only"
aws ec2 authorize-security-group-ingress        \
    --group-name $SEC_GRP --port 22 --protocol tcp \
    --cidr $LOCAL_IP/32

echo "setup rule allowing HTTP (port 5000) access to $LOCAL_IP only"
aws ec2 authorize-security-group-ingress        \
    --group-name $SEC_GRP --port 5000 --protocol tcp \
    --cidr $LOCAL_IP/32

UBUNTU_18_04_AMI="ami-013f17f36f8b1fefb"

echo "Creating ubuntu-bionic-18.04-amd64-server instance..."
RUN_INSTANCES=$(aws ec2 run-instances   \
    --image-id $UBUNTU_18_04_AMI        \
    --instance-type t2.micro            \
    --key-name $KEY_NAME                \
    --security-groups $SEC_GRP)

echo "Waiting for instance creation..."
aws ec2 wait instance-running --instance-ids $INSTANCE_ID

PUBLIC_IP=$(aws ec2 describe-instances  --instance-ids $INSTANCE_ID |
    jq -r '.Reservations[0].Instances[0].PublicIpAddress'
)

INSTANCE_ID=$(echo $RUN_INSTANCES | jq -r '.Instances[0].InstanceId')
echo "New instance $INSTANCE_ID @ $PUBLIC_IP was created"

echo "cloning code from remote repository"
git clone $REPO_URL
if [ ! -d "$REPO_NAME" ]; then
  echo "Failed to clone the source code. aborting deployment."
  exit
fi
cd $REPO_NAME || exit
src_file_name=$(ls ./*.py)
scp -i $KEY_PEM -o "StrictHostKeyChecking=no" -o "ConnectionAttempts=60" $src_file_name ubuntu@$PUBLIC_IP:/home/ubuntu/

echo "setup production environment"
ssh -i $KEY_PEM -o "StrictHostKeyChecking=no" -o "ConnectionAttempts=10" ubuntu@$PUBLIC_IP <<EOF
    sudo apt update
    sudo apt-get install -y git python3-pip
    pip3 install flask pandas
    # run app
    export FLASK_APP=$src_file_name
    nohup python3 -m flask run --host=0.0.0.0
    exit
EOF

