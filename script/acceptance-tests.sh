#!/bin/bash

set -eo pipefail

FOUNDRY_PROFILE=ir forge build
cd test/Acceptance
./Scripts/generate-contract-scripts.sh

swift test

cd ../../