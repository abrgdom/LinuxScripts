#!/bin/bash

# Ensure the script is run with sudo rights
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (sudo)"
  exec sudo "$0" "$@"
  exit 1
fi

# Function to prompt for input and ensure a value is provided
prompt_for_value() {
    local prompt=$1
    local var
    while true; do
        read -p "$prompt: " var
        if [ -n "$var" ]; then
            echo "$var"
            return
        else
            echo "A value must be provided."
        fi
    done
}

# Function to check if ACL components are installed and install if necessary
check_install_acl() {
    if ! dpkg -s acl &>/dev/null; then
        echo "ACL package is not installed. Installing..."
        sudo apt update
        sudo apt install acl -y
        if [ $? -ne 0 ]; then
            echo "Failed to install ACL package. Exiting."
            exit 1
        fi
        echo "ACL package installed successfully."
    else
        echo "ACL package is already installed."
    fi
}

# Function to ensure correct ownership and permissions, set setgid bit, and create default ACLs
setup_directory() {
    local directory=$1
    local owner=$2
    local group=$3

	# Create the directory if it doesn't exist
    if [ ! -d "$directory" ]; then
        echo "Directory $directory does not exist. Creating it..."
        mkdir -p $directory
    fi

    # Ensure correct ownership and permissions on directory
    sudo chown $owner:$group $directory
    sudo chmod 775 $directory

    # Set the setgid bit on the directory
    sudo chmod g+s $directory

    # Create default ACLs for directory
    sudo setfacl -R -m u::rwx $directory
    sudo setfacl -R -m g::rwx $directory
    sudo setfacl -R -m o::rx $directory
    sudo setfacl -R -m d:u::rwx $directory
    sudo setfacl -R -m d:g::rwx $directory
    sudo setfacl -R -m d:o::rx $directory
    sudo setfacl -R -m mask::rwx $directory
}

# Function to create group if it does not exist
create_group_if_not_exists() {
    local group=$1
    if ! getent group $group > /dev/null; then
        echo "Group $group does not exist. Creating..."
        sudo groupadd $group
        if [ $? -ne 0 ]; then
            echo "Failed to create group $group. Exiting."
            exit 1
        fi
        echo "Group $group created successfully."
    else
        echo "Group $group already exists."
    fi
}

# Check and install ACL components if necessary
check_install_acl

# Main script starts here
echo "=== Setting up directory ==="

# Prompt for variables
directory=$(prompt_for_value "Enter Directory")
owner=$(prompt_for_value "Enter Owner")
group=$(prompt_for_value "Enter Group")

# Create group if it does not exist
create_group_if_not_exists $group

# Ensure correct ownership, permissions, set setgid bit, and create default ACLs
setup_directory $directory $owner $group

# Output the ACL settings of the directory
echo "=== ACL settings for $directory ==="
getfacl $directory

echo "Setup complete for $directory."