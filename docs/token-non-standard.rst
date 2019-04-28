
.. _token-non-standard:

=======================
Non Standard Behaviours
=======================

``SecurityToken`` and ``NFToken`` are based upon the `ERC20 Token
Standard <https://theethereum.wiki/w/index.php/ERC20_Token_Standard>`__, however they deviate in several areas.

Issuer Balances
===============

Tokens held by the issuer will always be at the address of the IssuingEntity contract.  ``TokenBase.treasurySupply()`` returns the same result as ``TokenBase.balanceOf(TokenBase.issuer())``.

As a result, the following non-standard behaviours exist:

* Any address associated with the issuer can transfer tokens from the IssuingEntity contract using ``TokenBase.transfer``.
* Attempting to send tokens to any address associated with the issuer will result in the tokens being sent to the IssuingEntity contract.

Token Transfers
===============

The following behaviours deviate from ERC20 relating to token transfers:

* Transfers of 0 tokens will revert with an error string "Cannot send 0 tokens".
* If the caller and sender addresses are both associated to the same ID, ``TokenBase.transferFrom`` may be called without giving prior approval. In this way an investor can easily recover tokens when a private key is lost or compromised.
* The issuer may call ``TokenBase.transferFrom`` to move tokens between any addresses without prior approval. Transfers of this type must still pass the normal checks, with the exception that the sending address may be restricted.  In this way the issuer can aid investors with token recovery in the event of a lost or compromised private key, or force a transfer in the event of a court order.
