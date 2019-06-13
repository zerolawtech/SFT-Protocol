# SFT-Protocol/tests

Unit testing of this project is performed with [Brownie](https://github.com/HyperLink-Technology/brownie).

To run the tests:

```bash
$ brownie test
```

## Organization

Tests for SFT are sorted by the main contract being tested, then optionally by the main contract being interacted with and the methods being called.

## Subfolders

* `custodians`: Test folders for custodian contracts.
* `modules`: Test folders for module contracts.

## Test Folders

* `IssuingEntity`: Tests that target [IssuingEntity](../contracts/IssuingEntity.sol).
* `KYCIssuer`: Tests that target [KYCIssuer](../contracts/KYCIssuer.sol).
* `KYCRegistrar`: Tests that target [KYCRegistrar](../contracts/KYCRegistrar.sol).
* `NFToken`: Tests that target [NFToken](../contracts/NFToken.sol).
* `OwnedCustodian`: Tests that target [OwnedCustodian](../contracts/custodians/OwnedCustodian.sol).
* `SecurityToken`: Tests that target [SecurityToken](../contracts/SecurityToken.sol).