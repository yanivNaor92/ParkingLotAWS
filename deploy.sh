KEY_NAME="parking-lot-`date +'%N'`"
KEY_PEM="$KEY_NAME.pem"

echo "checking all necessary tools are installed"
if ! command -v jq &> /dev/null; then
    echo "jq could not be found, pleas install it and run the script again"
else
  if ! command -v aws &> /dev/null; then
    echo "aws could not be found, pleas install it, configure your aws account, and run the script again"
  fi
fi
echo "all necessary tools are present"

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

INSTANCE_ID=$(echo $RUN_INSTANCES | jq -r '.Instances[0].InstanceId')

echo "Waiting for instance $INSTANCE_ID to be created... (This might take several minutes)"
aws ec2 wait  instance-status-ok --instance-ids $INSTANCE_ID

PUBLIC_IP=$(aws ec2 describe-instances  --instance-ids $INSTANCE_ID |
    jq -r '.Reservations[0].Instances[0].PublicIpAddress'
)

INSTANCE_ID=$(echo $RUN_INSTANCES | jq -r '.Instances[0].InstanceId')
echo "New instance $INSTANCE_ID @ $PUBLIC_IP was created"

echo "setup production environment"
ssh -i $KEY_PEM -o "StrictHostKeyChecking=no" -o "ConnectionAttempts=10" ubuntu@$PUBLIC_IP << "EOF"
    sudo apt update
    sudo apt-get install -y git python3-pip
    pip3 install flask pandas
    echo "cloning code from remote repository"
    git clone https://github.com/yanivNaor92/ParkingLotAWS.git
    cd ParkingLotAWS || exit
    src_file_name=$(ls ./*.py)
    # run app
    server_ip=$(curl ipinfo.io/ip)
    echo "The server is running at http://${server_ip}:5000"
    export FLASK_APP=$src_file_name; export FLASK_ENV=development; nohup python3 -m flask run --host=0.0.0.0
    exit
EOF
