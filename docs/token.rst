.. _token:

#####
Token
#####

Each token contract represents a single class of securities from an issuer. Token contracts are based on the `ERC20 Token
Standard <https://theethereum.wiki/w/index.php/ERC20_Token_Standard>`__. Depending on the use case, there are two token implementations:

* `SecurityToken.sol <https://github.com/HyperLink-Technology/SFT-Protocol/tree/master/contracts/SecurityToken.sol>`__ is used for the issuance of non-certificated (book entry) securities. These tokens are fungible.
* `NFToken.sol <https://github.com/HyperLink-Technology/SFT-Protocol/tree/master/contracts/NFToken.sol>`__ is used for the issuance of certificated securities. These tokens are non-fungible.

Both contracts are derived from a common base `Token.sol <https://github.com/HyperLink-Technology/SFT-Protocol/tree/master/contracts/bases/Token.sol>`__.

Token contracts include :ref:`multisig` and :ref:`modules` via the associated :ref:`issuing-entity` contract. See the respective documents for more detailed information.

This documentation only explains contract methods that are meant to be accessed directly. External methods that will revert unless called through another contract, such as ``IssuingEntity`` or modules, are not included.

Because of significant differences in the contracts, ``SecurityToken`` and ``NFToken`` are documented seperately.

.. toctree::    :maxdepth: 2

    security-token.rst
    nftoken.rst
    token-non-standard.rst
