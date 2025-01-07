# Acceptance Tests

Acceptance tests verify the behavior of QuarkBuilder with human-digestible tests.

## For QuarkBuilder changes, re-gen via:

```sh
legend-scripts> FOUNDRY_PROFILE=ir forge build
```

Then in `test/Acceptance/` run:

```sh
legend-scripts/tests/Acceptance> ./Scripts/generate-contract-scripts.sh
```

## Running Tests

```sh
legend-scripts/tests/Acceptance> swift test
```

Alternatively, generate and run tests in one step

```sh
legend-scripts> ./script/acceptance-tests.sh
```

## Example Test

```swift
AcceptanceTest(
    name: "Alice transfers 10 USDC to Bob on Ethereum",
    given: [.tokenBalance(.alice, (100, .usdc), .ethereum)],
    when: .transfer(from: .alice, to: .bob, amount: (10, .usdc), on: .ethereum),
    expect: .revert(.notUnwrappable)
)
```
