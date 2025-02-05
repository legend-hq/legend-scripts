#!/bin/bash

set -eo pipefail

if [ -n "$RPC_URL" ]; then
  rpc_args="--rpc-url $RPC_URL"
else
  echo "Error: RPC_URL is not set"
  exit 1
fi

if [ -n "$DEPLOYER_PK" ]; then
  wallet_args="--private-key $DEPLOYER_PK"
else
  wallet_args="--unlocked"
fi

if [ -n "$ETHERSCAN_API_KEY" ]; then
  etherscan_args="--verify --etherscan-api-key $ETHERSCAN_API_KEY"
else
  echo "Error: ETHERSCAN_API_KEY is not set"
  exit 1
fi

if [ -z "$DEPLOYMENT_CHAIN_ID" ]; then
  echo "Error: DEPLOYMENT_CHAIN_ID is not set"
  exit 1
fi

echo "Building contract artifacts..."
FOUNDRY_PROFILE=ir forge build

# Find all Solidity source files
src_files=$(find ./src -maxdepth 1 -name "*.sol")

# Initialize indexed arrays
ignored_contracts=("Quotecall" "Paycall" "GetDrip")
contract_paths=()
bytecodes=()
existing_deploys=()
failed_deploys=()
successful_deploys=()
already_verified=()
successful_verifications=()
failed_verifications=()

# Define a function to print the lists
print_lists() {
  echo "Successful Deploys:"
  for contract in "${successful_deploys[@]}"; do
    echo "$contract"
  done

  echo "Failed Deploys:"
  for contract in "${failed_deploys[@]}"; do
    echo "$contract"
  done

  echo "Existing Deploys:"
  for contract in "${existing_deploys[@]}"; do
    echo "$contract"
  done
}

# Set a trap to catch exit signals and run the print_lists function
trap print_lists EXIT

# Process each Solidity source file
for src_file in $src_files; do
  file_name=$(basename "$src_file")

  # Specify the output directory for the contract
  out_dir="./out/$file_name"

  # Ensure that the output directory exists and contains files
  if [ ! -d "$out_dir" ]; then
    echo "Directory '$out_dir' does not exist, skipping..."
    continue
  fi

  bytecode=""
  # Iterate over all JSON files in the contract's output directory and extract their bytecode
  for out_file in "$out_dir"/*.json; do
    contract_name=$(basename "$out_file" .json)
    contract_paths+=("$src_file:$contract_name")

    bytecode=$(jq -r '.bytecode.object' "$out_file")

    if [ "$bytecode" != "null" ] && [ -n "$bytecode" ]; then
      bytecodes+=("$bytecode")
    else
      echo "No valid bytecode found in: $out_file" # Debugging line
    fi
  done
done

for i in "${!contract_paths[@]}"; do
  contract_path="${contract_paths[$i]}"
  bytecode="${bytecodes[$i]}"

  # Check if the contract name should be ignored
  for ignored in "${ignored_contracts[@]}"; do
    if [[ "$contract_path" == *"$ignored"* ]]; then
      echo "Skipping $contract_path (matches ignored contract: $ignored)"
      continue 2  # Skip to the next contract in contract_paths
    fi
  done

  # Check if the code exists on-chain
  output=$(FOUNDRY_PROFILE=ir BYTECODE=$bytecode forge script \
      $rpc_args \
      script/verify_contracts/CodeExists.s.sol:CodeExists)
  code_exists=$(echo "$output" | grep "Code Exists:" | cut -d: -f2 | tr -d ' ')

  if [ "$code_exists" == "true" ]; then
    echo "Code already exists for '$contract_path', skipping..."
    existing_deploys+=("$contract_path")
    continue
  else
    echo "Code does not exist for '$contract_path'"
  fi

  echo "Attempting to deploy $contract_path"

  # Saves the code for the script
  output=$(FOUNDRY_PROFILE=ir BYTECODE=$bytecode forge script \
      $rpc_args \
      $wallet_args \
      $etherscan_args \
      "--broadcast" \
      script/deploy_contracts/DeployCode.s.sol:DeployCode)
  address=$(echo "$output" | grep "Code Address:" | cut -d: -f2 | tr -d ' ')

  # TODO: The forge deploy script currently exits the entire script upon a failed deploy.
  #       I haven't figured out a way to capture it without drastically increasing complexity,
  #       so I'll leave it as a non-urgent TODO
  if [ -z "$address" ] || [ "$address" == "0x" ]; then
    echo "Deploy failed for $contract_path"
    failed_deploys+=("$contract_path")
    continue
  else
    echo "Deploy succeeded for $contract_path at address $address"
    successful_deploys+=("$contract_path at address $address")
  fi
done
