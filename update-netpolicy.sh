#!/bin/bash

# Script to update the wazuh-manager-master network policy to allow egress to Postfix on port 25/TCP

# Variables
NAMESPACE="wazuh"
POLICY_NAME="wazuh-manager-master"
POSTFIX_LABEL="app: postfix-relay"
PORT="25"
PROTOCOL="TCP"

# Temporary file to store the updated policy
TEMP_POLICY_FILE="/tmp/updated-policy.yaml"

# Function to check if the network policy exists
check_policy_exists() {
  kubectl get networkpolicy $POLICY_NAME -n $NAMESPACE &> /dev/null
  if [ $? -ne 0 ]; then
    echo "Error: Network policy $POLICY_NAME does not exist in namespace $NAMESPACE."
    exit 1
  fi
}

# Function to retrieve the current network policy
retrieve_policy() {
  kubectl get networkpolicy $POLICY_NAME -n $NAMESPACE -o yaml > $TEMP_POLICY_FILE
  if [ $? -ne 0 ]; then
    echo "Error: Failed to retrieve network policy $POLICY_NAME."
    exit 1
  fi
}

# Function to add the egress rule if it doesn't already exist
add_egress_rule() {
  # Check if the egress rule already exists
  if grep -q "app: postfix-relay" $TEMP_POLICY_FILE && grep -q "port: 25" $TEMP_POLICY_FILE; then
    echo "Egress rule for Postfix on port 25 already exists. No changes needed."
    rm $TEMP_POLICY_FILE
    exit 0
  fi

  # Add the egress rule
  sed -i '/egress:/a\
  - to:\
    - podSelector:\
        matchLabels:\
          app: postfix-relay\
    ports:\
    - port: 25\
      protocol: TCP' $TEMP_POLICY_FILE

  if [ $? -ne 0 ]; then
    echo "Error: Failed to add egress rule to the policy."
    exit 1
  fi
}

# Function to apply the updated policy
apply_policy() {
  kubectl apply -f $TEMP_POLICY_FILE
  if [ $? -ne 0 ]; then
    echo "Error: Failed to apply updated network policy."
    exit 1
  fi
  echo "Successfully applied updated network policy."
}

# Function to clean up temporary file
cleanup() {
  rm -f $TEMP_POLICY_FILE
}

# Main script execution
check_policy_exists
retrieve_policy
add_egress_rule
apply_policy
cleanup

# Optional: Verify the changes
echo "Verifying the updated network policy..."
kubectl get networkpolicy $POLICY_NAME -n $NAMESPACE -o yaml | grep -A 5 "egress:"

echo "Script execution completed."

