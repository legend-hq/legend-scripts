#!/bin/bash

set -eo pipefail

FOUNDRY_PROFILE=ir forge build --skip test --skip script
cd test/Acceptance
./Scripts/generate-contract-scripts.sh

swift test

cd ../../