# SFT Protocol

## Description

The SFT protocol is a set of compliance-oriented smart contracts built on the Ethereum blockchain that allow for the tokenization of debt and equity based securities. It provides a robust, flexible framework allowing issuers and investors to retain regulatory compliance throughout primary issuance and multi-jurisdictional secondary trading.

## How It Works

SFT expands upon the ERC20 token standard. Tokens are transferred via the ``transfer`` and ``transferFrom`` functions, however the transfer will only succeed if approved by a series of permissioning modules. A call to ``checkTransfer`` returns true if the transfer is possible. The standard configuration includes checking a KYC/AML whitelist, tracking investor counts and limits, and restrictions on countries and accredited status. By implementing other modules a variety of additional functionality is possible so as to allow compliance to laws in the countries of the issuer and investors.

## Documentation

The SFT Protocol documentation is hosted at [Read the docs](https://sft-protocol.readthedocs.io).

## Testing and Deployment

Unit testing and deployment of this project is performed with [brownie](https://github.com/iamdefinitelyahuman/brownie).

## Third-Party Integration

See the [Third Party Integration](https://sft-protocol.readthedocs.io/en/latest/third-party-integration.html) page for in-depth details.

## License

This project is licensed under the [Apache 2.0](https://www.apache.org/licenses/LICENSE-2.0.html) license.
