Third Party Integration
=======================

KYC Registrar
-------------

To setup an investor registry, deploy
`KYCRegistrar.sol <../contracts/KYCRegistrar.sol>`__. Owner addresses
will then be able to add investors using ``addInvestor`` or approve
other whitelisting authorities with ``addAuthority``. See the
`KYCRegistrar <./kyc-registrar.md>`__ page for a detailed explanation of
how to use this contract.

Issuing Tokens
--------------

Issuing tokens and being able to transfer them requires the following
steps:

1. Deploy `IssuingEntity.sol <../contracts/IssuingEntity.sol>`__.
2. Call ``IssuingEntity.setRegistrar`` to add one or more investor
   registries. You may maintain your own registry and/or use those
   belonging to trusted third parties.
3. Deploy `SecurityToken.sol <../contracts/SecurityToken.sol>`__. Enter
   the address of the issuer contract from step 1 in the constructor.
   The total supply of tokens will be initially creditted to the issuer.
4. Call ``IssuingEntity.addToken`` to attach the token to the issuer.
5. Call ``IssuingEntity.setCountries`` to approve investors from
   specific countries to hold the tokens.

At this point, the issuer will be able to transfer tokens to any address
that has been whitelisted by one of the approved investor registries *if
the investor meets the country and rating requirements*.

Note that the issuer's balance is assigned to the IssuingEntity
contract. The issuer can transfer these tokens with a normal call to
``SecurityToken.transfer`` from any approved address. Sending tokens to
any address associated with the issuer will increase the balance on the
IssuingEntity contract.

You can also introduce further limitations on investor counts or attach
optional modules to add more bespoke functionality. See the
`IssuingEntity <./issuing-entity.md>`__ and
`SecurityToken <./security-token.md>`__ pages for detailed explanations
of how to use these contracts.

Transferring Tokens
-------------------

SecurityToken.sol is based on the `ERC20 Token
Standard <https://theethereum.wiki/w/index.php/ERC20_Token_Standard>`__.
Token transfers may be performed in the same ways as any token using
this standard. However, in order to send or receive tokens you must
also:

-  Be approved in one of the KYC registries associated to the token
   issuer
-  Meet the approved country and rating requirements as set by the
   issuer
-  Pass any additional checks set by the issuer

You can check if a transfer will succeed without performing a
transaction by calling the ``checkTransfer`` function of the token
contract.

Restrictions imposed on investor limits, approved countries and minimum
ratings are only checked when receiving tokens. Unless an address has
been explicitely blocked, it will always be able to send an existing
balance. For example, an investor may purchase tokens that are only
require being accreditted, and then later their accreditation status
expires. The investor may still transfer the tokens they already have,
but may not receive any more tokens.

Transferring a balance between two addresses associated with the same
investor ID does not have the same restrictions imposed, as there is no
change of ownership. An investor with multiple addresses may call
``transferFrom`` to move tokens from any of their addresses without
first using the ``approve`` method. The issuer can also use
``transferFrom`` to move any investor's tokens, without prior approval.

See the `SecurityToken <./security-token.md>`__ page for a detailed
explanation of how to use this contract.

Custodians
----------

To set up a custodian contract to send and receive tokens, you must
deploy it and then attach it to an IssuingEntity with
``IssuingEntity.addCustodian``. At this point, investors may send tokens
into the custodian contract just like they would any other address.

The ``Custodian.transfer`` function allows you to send tokens out of the
contract. You may modify the list of benficial owners using
``addInvestors`` and ``removeInvestors``.

See the `Custodian <./custodian.md>`__ page for a detailed explanation
of how to use this contract.
