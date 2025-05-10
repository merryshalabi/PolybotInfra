#!/bin/bash

# Display help if requested
if [ "$1" = "--help" ]; then
  echo "Usage: $0 <BASTION_IP> <TARGET_PRIVATE_IP> [COMMAND]"
  echo "  BASTION_IP          - The public IP address of the Bastion host."
  echo "  TARGET_PRIVATE_IP   - The private IP address of the target instance (Polybot or YOLO)."
  echo "  COMMAND             - (Optional) Command to run on the target instance."
  echo "Environment:"
  echo "  KEY_PATH            - Path to the SSH private key file."
  exit 0
fi

# Check for KEY_PATH environment variable
if [ -z "$KEY_PATH" ]; then
  echo "Error: KEY_PATH environment variable is not set. Set it to the path of your private SSH key."
  exit 5
fi

# Validate that the specified SSH key file exists
if [ ! -f "$KEY_PATH" ]; then
  echo "Error: The SSH key file specified in KEY_PATH does not exist: $KEY_PATH"
  exit 5
fi

chmod 600 "$KEY_PATH"  # Ensure secure permissions

# Validate Bastion IP
if [ -z "$1" ]; then
  echo "Error: Please provide the Bastion host public IP address."
  exit 5
fi

BASTION_IP="$1"

# If only Bastion IP is provided, connect to Bastion directly
if [ -z "$2" ]; then
  ssh -i "$KEY_PATH" ubuntu@$BASTION_IP
  exit 0
fi

TARGET_PRIVATE_IP="$2"
shift 2

# If no command is provided, open an SSH session to the target instance
if [ -z "$1" ]; then
  ssh -i "$KEY_PATH" \
      -o StrictHostKeyChecking=no \
      -o ProxyCommand="ssh -i $KEY_PATH -W %h:%p ubuntu@$BASTION_IP" \
      ubuntu@$TARGET_PRIVATE_IP
  exit 0
fi

# If a command is provided, run it on the target instance
ssh -i "$KEY_PATH" \
    -o StrictHostKeyChecking=no \
    -o ProxyCommand="ssh -i $KEY_PATH -W %h:%p ubuntu@$BASTION_IP" \
    ubuntu@$TARGET_PRIVATE_IP "$@"

