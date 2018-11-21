.. _issuing-entity:

##############
Issuing Entity
##############

IssuingEntity contracts hold shared compliance logic for all security tokens created by a single issuer.

Each issuer contract includes standard SFT protocol :ref:`multisig` and :ref:`modules` functionality. See the respective documents for detailed information on these components.

It may be useful to also view the `IsssuingEntity.sol <https://github.com/SFT-Protocol/security-token/tree/master/contracts/IssuingEntity.sol>`__ source code while reading this document.

Components
==========

IssuingEntity contracts are based on the following key components:

-  **Issuers** are entities that create tokenized securities using the
   protocol. Each issuer owns one IssuingEntity contract and one or more
   SecurityToken contracts.
-  **Security tokens**, or just tokens, are ERC-20 compliant tokens created by
   an issuer.
-  **Registrars** are whitelist contracts that associate ethereum addresses
   to specific investors.

Deployment
==========

.. method:: IssuingEntity.constructor(address[] _owners, uint32 _threshold,address[] _owners, uint32 _threshold)

Deploying an IssuingEntity contract requires 2 arguments in the constructor:

-  ``address[] _owners``: One or more addresses to associate with the
   contract owner. The address deploying the contract is not implicitly
   included within the owner list.
-  ``uint32 _threshold``: The number of calls required for the owner to
   perform a multi-sig action.

The ID of the owner is generated as a keccak of the contract address and available from the public getter ``ownerID``.

Functionality
=============

Although this is by far the largest contract in the protocol, the majority of the functionality is accessed indirectly through other contracts.

Adding and Restricting Tokens
-----------------------------
An issuer must associate :ref:`security-token` contracts with their IssuingEntity contract before transfers are possible.  This is done via ``addToken``.

Tokens may be individually locked or unlocked with ``setTokenRestriction``.  All tokens can be locked or unlocked in a single call with ``setGlobalRestriction``.

Identifying Investors
---------------------

Investors must be identified via a :ref:`kyc-registrar` before they can send or receive tokens. To allow this, an issuer must associate one or more registries with ``setRegistrar``.

The following view functions can be used to obtain investor information:

* ``getID``: Returns the investor ID associated with an address.
* ``getInvestorRegistrar``: Returns the registrar address that an investor ID is associated with.

It is also possible to remove a registrar using ``setRegistrar``. Once removed, any investors that were identified through that registrar will be unable to send or receive tokens until they are identified through another associated registrar. Transfer attempts will revert with the message "Registrar restricted".

Investors may be restricted by the issuer with ``setInvestorRestriction``. This can only be used to block an investor that would otherwise be able to hold the tokens, it cannot be used to whitelist investors who are not listed in an associated registrar.

Setting Investor Limits
-----------------------

Investor limits can be set globally, by country, by investor rating, or by a combination. Some possible examples:

* Maximum of 2000 total investors, of which 150 may be from the USA, of which 35 of may be unaccreditted.
* No limit on total investors, maximum of 150 per country in the European Union, all investors must be accreditted, USA investors are blocked

All investor limits are stored in uint32[8] arrays. The first value in each array is the total limit, the remaining value correspond to the limits for each investor rating.  A value of 0 means there is no limit.

Global limits are set or modified using ``setInvestorLimits``. Current investor counts and limits can be viewed by calling ``getInvestorCounts``.

The issuer must explicitely approve each country from which investors are allowed to purchase tokens. This is done with one of two functions, depending on which additional limitations are to be set:

* ``setCountry``: Approves one country per call and can set specific limits for each investor rating. Can also be used to restrict a previously approved country.
* ``setCountries``: Approves many countries at once but can only set a total investor limit per country.

It is possible for an issuer to set a limit that is lower than the current investor count. When a limit is met or exceeded existing investors are still able to receive tokens, but new investors are blocked.

Custodians
----------

* ``addCustodian``: Approves a custodian contract to send and receive tokens associated with the issuer.
* ``setBeneficialOwners``: Modifies the list of beneficial owners associated with the custodian.
* ``setInvestorRestriction``: Can be used by the issuer to restrict or unrestrict a custodian.


Document Hashes
---------------

An issuer can record the bytes32 hash of a legal document using ``setDocumentHash``. The hash is stored in a (string => bytes32) mapping and can be queried later using ``getDocumentHash``.  Once a hash is recorded, the issuer can then distrubute the document electronically and investors can verify the authenticity by generating the hash themselves and comparing it to the blockchain record.

Modules
-------

Integration
===========
