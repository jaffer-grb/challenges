#!/bin/bash

# Change these values as per your requirements
INSTANCE_TYPE="t2.micro"
AMI_ID="ami-072ec8f4ea4a6f2cf"  # Replace with the appropriate AMI ID for your desired instance image
KEY_PAIR_NAME="linux_test_key"  # Replace with your key pair name
SECURITY_GROUP_ID="sg-087fb315a0de0c9c0"  # Replace with your security group ID
COUNT=5  # Number of instances to create

for ((i=1; i<=COUNT; i++)); do
    instance_id=$(aws ec2 run-instances \
        --image-id "$AMI_ID" \
        --instance-type "$INSTANCE_TYPE" \
        --key-name "$KEY_PAIR_NAME" \
        --security-group-ids "$SECURITY_GROUP_ID" \
        --query 'Instances[0].InstanceId' \
        --output text)

    if [ -z "$instance_id" ]; then
        echo "Instance creation failed for instance $i"
    else
        echo "Instance $instance_id created successfully"
    fi
done

sleep 30

# Function to get the instance ID of running EC2 instances
get_running_instance_ids() {
    aws ec2 describe-instances \
        --query "Reservations[].Instances[?State.Name == 'running'].InstanceId" \
        --output text
}

# Function to select two random instances from the list
select_random_instances() {
    running_instance_ids=($(get_running_instance_ids))
    total_running_instances=${#running_instance_ids[@]}

    if (( total_running_instances < 2 )); then
        echo "There are fewer than two running instances. Exiting."
        exit 1
    fi

    echo "Running Instances:"
    for (( i=0; i<total_running_instances; i++ )); do
        echo "$(( i + 1 )): ${running_instance_ids[i]}"
    done

    read -p "Select the first instance (enter the number): " selected_index_1
    read -p "Select the second instance (enter the number): " selected_index_2

    if (( selected_index_1 < 1 || selected_index_1 > total_running_instances || selected_index_2 < 1 || selected_index_2 > total_running_instances || selected_index_1 == selected_index_2 )); then
        echo "Invalid selection. Please enter valid numbers for two different instances."
        exit 1
    fi

    instance_id_1="${running_instance_ids[selected_index_1 - 1]}"
    instance_id_2="${running_instance_ids[selected_index_2 - 1]}"

    echo "Selected Instance 1: $instance_id_1"
    echo "Selected Instance 2: $instance_id_2"

    # Return the instance IDs as an array
    selected_instances=("$instance_id_1" "$instance_id_2")
}

# Function to toggle the state of an EC2 instance (stop to run or run to stop)
toggle_instance_state() {
    instance_id=$1
    instance_state=$(aws ec2 describe-instances \
        --instance-ids "$instance_id" \
        --query 'Reservations[].Instances[0].State.Name' \
        --output text)

    case "$instance_state" in
        "running")
            echo "Stopping instance $instance_id"
            aws ec2 stop-instances --instance-ids "$instance_id"
            ;;
        "stopped")
            echo "Starting instance $instance_id"
            aws ec2 start-instances --instance-ids "$instance_id"
            ;;
        *)
            echo "Instance $instance_id is in an unknown state: $instance_state"
            ;;
    esac
}
# Main script
select_random_instances
for instance_id in "${selected_instances[@]}"; do
    toggle_instance_state "$instance_id"
done

