#!/bin/bash

set -eo pipefail

if [ -n "$RPC_URL" ]; then
  rpc_args="--rpc-url $RPC_URL"
else
  echo "Error: RPC_URL is not set"
  exit 1
fi

if [ -z "$VERIFICATION_CHAIN_ID" ]; then
  echo "Error: VERIFICATION_CHAIN_ID is not set"
  exit 1
fi

if [ -z "$ETHERSCAN_API_KEY" ]; then
  echo "Error: ETHERSCAN_API_KEY is not set"
  exit 1
fi

echo "Building contract artifacts..."
FOUNDRY_PROFILE=ir forge build

# Find all Solidity source files
src_files=$(find ./src -maxdepth 1 -name "*.sol")

# Initialize indexed arrays
contract_paths=()
bytecodes=()
already_verified=()
successful_verifications=()
failed_verifications=()

# Define a function to print the lists
print_lists() {
  echo "Already Verified Contracts:"
  for contract in "${already_verified[@]}"; do
    echo "$contract"
  done

  echo "Successful Verifications:"
  for contract in "${successful_verifications[@]}"; do
    echo "$contract"
  done

  echo "Failed Verifications:"
  for contract in "${failed_verifications[@]}"; do
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

  # Check if the code exists on-chain
  output=$(FOUNDRY_PROFILE=ir BYTECODE=$bytecode forge script \
      $rpc_args \
      script/verify_contracts/CodeExists.s.sol:CodeExists)

  code_exists=$(echo "$output" | grep "Code Exists:" | cut -d: -f2 | tr -d ' ')

  if [ "$code_exists" != "true" ]; then
    echo "Code does not exist for '$contract_path', skipping..."
    continue
  fi

  # Get the code address for the script
  output=$(FOUNDRY_PROFILE=ir BYTECODE=$bytecode forge script \
      $rpc_args \
      script/verify_contracts/GetCodeAddress.s.sol:GetCodeAddress)
  address=$(echo "$output" | grep "Code Address:" | cut -d: -f2 | tr -d ' ')

  if [ -z "$address" ] || [ "$address" == "0x" ]; then
    echo "Failed to retrieve code address for bytecode $contract_path"
    continue
  fi

  echo "Attempting to verify $contract_path at $address"

  # Attempt to verify the contract
  verification_output=$(FOUNDRY_PROFILE=ir forge verify-contract $address $contract_path --watch --chain-id $VERIFICATION_CHAIN_ID)

  if echo "$verification_output" | grep -q "successfully verified"; then
    echo "Verification succeeded for $contract_path"
    successful_verifications+=("$contract_path")
  elif echo "$verification_output" | grep -q "already verified"; then
    echo "$contract_path is already verified"
    already_verified+=("$contract_path")
  else
    echo "Verification failed for $contract_path"
    failed_verifications+=("$contract_path")
  fi
done
