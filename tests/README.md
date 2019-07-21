# SFT-Protocol/tests

Unit testing of this project is performed with [Brownie](https://github.com/iamdefinitelyahuman/brownie) and [Pytest](https://github.com/pytest-dev/pytest).

To run the tests:

```bash
$ pytest tests/
```

A [dockerfile](Dockerfile) is available if you are experiencing issues.

## Organization

Tests for SFT are sorted by the main contract being tested, then optionally by the main contract being interacted with and the methods being called.

## Subfolders

* `custodians`: Test folders for custodian contracts.
* `modules`: Test folders for module contracts.

## Test Folders

* `IssuingEntity`: Tests that target [IssuingEntity](../contracts/IssuingEntity.sol).
* `KYCIssuer`: Tests that target [KYCIssuer](../contracts/KYCIssuer.sol).
* `KYCRegistrar`: Tests that target [KYCRegistrar](../contracts/KYCRegistrar.sol).
* `SecurityToken`: Tests that target [SecurityToken](../contracts/SecurityToken.sol).
