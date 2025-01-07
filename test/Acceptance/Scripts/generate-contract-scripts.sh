#!/bin/bash

set -eo pipefail

script_dir=$(dirname "${BASH_SOURCE[0]}")
swift_base_dir="$(readlink -f "${script_dir}/..")"
out_dir="$(readlink -f "${swift_base_dir}/../../out")"
source_out_dir="$(readlink -f "${swift_base_dir}/Sources/Acceptance/Contracts")"
contracts=("DeFiScripts" "Multicall" "QuotePay" "QuarkBuilder" "AcrossScripts" "WrapperScripts" "MorphoScripts")

cd "${swift_base_dir}"

for contract in "${contracts[@]}"; do
    contract_path="${out_dir}/${contract}.sol"
    if [ -d "${contract_path}" ]; then
        for file in "${contract_path}"/*.json; do
            echo "Generating ${contract} from $(basename "${file}")"
            swift run Geno "${file}" --outDir "${source_out_dir}" &
        done
    else
        echo "Contract ${contract} not found at ${contract_path}"
        exit 1
    fi
done

# wait for forked background Geno jobs to complete
wait

if command -v swiftformat >/dev/null 2>&1; then
    swiftformat "./Sources/Acceptance/Contracts/"*.swift
else
    echo "⚠️ SwiftFormat not found, skipping formatting"
fi
