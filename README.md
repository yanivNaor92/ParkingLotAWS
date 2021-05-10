# ParkingLotAWS
## A cloud-based system for managing a parking lot
This repository contains a simple python code that expose two APIs and simulating managing a parking lot.  
The code should be deployed and ran on an AWS EC2 instance.  

## Prerequisites
1. The following tools need to be installed on your local machine in order to run and deploy this code:  
1.1 python.  
1.2 AWS CLI.  
1.3 bash.  
1.4 jq.  
2. You need to have an active AWS account.  Visit [Amazon.com](https://aws.amazon.com/) if you need to create one.
3. Configure your AWS account by running the command 'aws configure' and enter the following values:  
3.1 AWS Access Key ID.  
3.2 AWS Secret Access Key.  
3.3 Default region name.  
3.4 Default output format.  
see [AWS Configuration Basics](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-quickstart.html) for more details.  


## API
The server exposes two HTTP endpoints:  
1. <b>POST /entry?plate=\<plate-number\>&parkingLot=\<parking-lot-number\></b>  
   Returns a ticket id.  
   For example, POST /entry?plate=123-123-123&parkingLot=382
2. <b>POST /exit?ticketId=\<ticket-id\></b>   
   Returns the license plate, total parked time, the parking lot id and the charge (based
   on 15 minutes increments).  
   For example, POST /exit?ticketId=1234

## Deployment
The file 'deploy.sh' contains a shell script for auto-deployment to an AWS EC2 instance.  
There is no need to create the EC2 instance in advance, the script will create it using the AWS CLI and will also take care of all the required configuration.  
After the script will finish its run (it might take several minutes since the instance is being created at runtime) the server should already be deployed and running on your new EC2 instance.  
You can access it via your browser in the instance public IP at port 5000.  
The EC2 public IP will be logged to the terminal by the deployment script and can also be seen in your AWS management console. 
The script uses a free-tier EC2 instance, so you will not be charged by AWS by creating the instance using this script.
