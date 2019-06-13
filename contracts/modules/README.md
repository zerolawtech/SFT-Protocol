# SFT-Protocol/contracts/modules

Optional modules that may be attached to core contracts as needed.

## Subfolders

* `bases`: Inherited base contracts used by modules.

## Contracts

* `bases/Modular.sol`: Contains `ModuleBase` and `STModuleBase` contracts. All modules **must** inherit one of these base contracts, or implement their functionality.
* `bases/Checkpoint.sol`: Base module for creating a single balance checkpoint for a token.
* `Dividend.sol`: Token module for paying out dividends denominated in ETH.
* `VestedOptions.sol`: `SecurityToken` module for issuing vested stock options.
