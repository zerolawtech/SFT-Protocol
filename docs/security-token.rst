.. _security-token:

##############
Security Token
##############

Each SecurityToken contract represents a single, fungible class of securities from an issuer. The contracts conforms to the ERC20 standard, with an additional ``checkTransfer`` function available to verify if a transfer will succeed.

Token contracts are associated to an :ref:`issuing-entity` and also implement :ref:`modules` functionality. Permissioning around transfers is achieved through these components. See the respective documents for more detailed information.

It may be useful to also view the `SecurityToken.sol<https://github.com/SFT-Protocol/security-token/tree/master/contracts/SecurityToken.sol>`__ source code while reading this document.

Components
==========

Deployment
==========

Deploying a SecurityToken contract requires 4 arguments in the constructor:

-  ``address _issuer``: The address of the IssuingEntity contract associated
   with this token.
-  ``string _name``: The full name of the token.
-  ``string _symbol``: The ticker symbol for the token.
-  ``uint256 _totalSupply``: The initial total supply of tokens to create.

The total supply of tokens is assigned to the issuer at the time of creation,
with a ``Transfer`` event firing to show them as moving from 0x00.

After the contract is deployed it must be associated with the issuer via
``IssuingEntity.addToken``. Token transfers are not possible until this is done.

Functionality
=============

SecurityToken expands upon and is fully compatible with the `ERC20 Token
Standard <https://theethereum.wiki/w/index.php/ERC20_Token_Standard>`__.

Total Supply
------------

There are three view functions relating to the total supply:

-  ``totalSupply``: Returns the total supply of tokens.
-  ``treasurySupply``: Returns the number of tokens held by the issuer.
-  ``circulatingSupply``: Returns the total supply, less the amount held by the issuer.


Balances and Allowances
--------------------------------

The standard ERC20 functions are available:

-  ``balanceOf``: Returns the token balance for a given address.
-  ``allowance``: Returns the number of tokens that a given address is approved to transfer for another address.


Token Transfers
-----------------





Integration
===========

Security Considerations
=======================
