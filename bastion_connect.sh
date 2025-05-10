#!/bin/bash

# Check if KEY_PATH environment variable is set (for Bastion)
if [ -z "$KEY_PATH" ]; then
  echo "KEY_PATH env var is expected"
  exit 5
fi

# Check if at least one argument (bastion IP) is provided
if [ -z "$1" ]; then
  echo "Please provide bastion IP address"
  exit 5
fi

BASTION_IP=$1
TARGET_IP=$2
COMMAND=${@:3}

# Determine the key to use for the target (Polybot or Yolo)
if [ "$TARGET_IP" == "10.0.1.208" ]; then
  TARGET_KEY="/home/ubuntu/merryPolybotKey.pem"
elif [ "$TARGET_IP" == "10.0.2.165" ]; then
  TARGET_KEY="/home/ubuntu/merryYoloKey.pem"
else
  echo "Unknown target IP. Make sure you are using the correct IPs."
  exit 5
fi

# If no target IP is provided, connect to Bastion only
if [ -z "$TARGET_IP" ]; then
  ssh -tt -i "$KEY_PATH" ubuntu@$BASTION_IP
else
  if [ -z "$COMMAND" ]; then
    # Connect to target (Polybot or Yolo) via Bastion using the correct key
    ssh -tt -i "$KEY_PATH" ubuntu@$BASTION_IP "ssh -tt -i $TARGET_KEY ubuntu@$TARGET_IP"
  else
    # Run command on target (Polybot or Yolo) via Bastion using the correct key
    ssh -tt -i "$KEY_PATH" ubuntu@$BASTION_IP "ssh -tt -i $TARGET_KEY ubuntu@$TARGET_IP \"$COMMAND\""
  fi
fi
