.. _issuing-entity:

##############
Issuing Entity
##############

IssuingEntity contracts hold shared compliance logic for all security tokens created by a single issuer. They are the central contract that an issuer uses to connect and interact with registrars, tokens and custodians.

Each issuer contract includes standard SFT protocol :ref:`multisig` and :ref:`modules` functionality. See the respective documents for detailed information on these components.

This documentation only explains contract methods that are meant to be accessed directly. External methods that will revert unless called through another contract, such as a token or module, are not included.

It may be useful to also view the `IsssuingEntity.sol <https://github.com/SFT-Protocol/security-token/tree/master/contracts/IssuingEntity.sol>`__ source code while reading this document.

Deployment
==========

The constructor declares the owner as per standard :ref:`multisig`.

.. method:: IssuingEntity.constructor(address[] _owners, uint32 _threshold)

    * ``_owners``: One or more addresses to associate with the contract owner. The address deploying the contract is not implicitly included within the owner list.
    * ``_threshold``: The number of calls required for the owner to perform a multi-sig action.

    The ID of the owner is generated as a keccak of the contract address and available from the public getter ``ownerID``.

Adding and Restricting Tokens
=============================

Tokens must be associated with the IssuingEntity contract before they can be transfered.

.. method:: IssuingEntity.addToken(address _token)

    Associates a :ref:`security-token` contract with the IssuingEntity.

.. method:: IssuingEntity.setTokenRestriction(address _token, bool _allowed)

    Restricts or unrestricts transfers of a token.  When a token is restricted, only the issuer may perform transfers.

.. method:: IssuingEntity.setGlobalRestriction(bool _allowed)

    Restricts or unrestricts transfers of all associated tokens. Modifying the global restriction does not affect individual token restrictions.

Identifying Investors
=====================

.. method:: IssuingEntity.setRegistrar(address _registrar, bool _allowed)

    Associates or removes a :ref:`kyc-registrar`.

    Investors must be identified before they can send or receive tokens. Before a transfer is completed, each associated registrar is called to check which IDs are associated to the transfer addresses.

    The address => ID association is stored within IssuingEntity. If a registrar is later removed it is impossible for another registrar to return a different ID for the address.

    When a registrar is removed, any investors that were identified through it will be unable to send or receive tokens until they are identified through another associated registrar. Transfer attempts will revert with the message "Registrar restricted".

.. method:: IssuingEntity.getID(address _addr)

    Returns the investor ID associated with an address. If the address is not saved in the contract, this call will query associated registrars.

.. method:: IssuingEntity.getInvestorRegistrar(bytes32 _id)

    Returns the registrar address associated with an investor ID. If the investor ID is not saved in the contract, this call will return 0x00.

.. method:: IssuingEntity.setInvestorRestriction(bytes32 _id, bool _allowed)

    Retricts or permits an investor from transferring tokens, based on their ID.

    This can only be used to block an investor that would otherwise be able to hold the tokens, it cannot be used to whitelist investors who are not listed in an associated registrar. When an investor is restricted, the issuer is still able to transfer tokens from their addresses.

Custodians
==========

**Custodian** are entities that are approved to hold tokens on behalf of multiple investors. Common examples of custodians include broker/dealers and secondary markets. Each custodian must be individually approved by an issuer before they can receive tokens.

Custodians interact with an issuer's investor counts differently from regular investors. When an investor transfers a balance into a custodian it does not increase the overall investor count, instead the investor is now included in the list of beneficial owners represented by the custodian. Even if the investor now has a balance of 0, they will be still be included in the issuer's investor count.

Each time a beneficial owner is added or removed from a custodian, the ``BeneficialOwnerSet`` event will fire. Filtering for this event can be used to keep an up-to-date record of which investors have tokens held by a custodian.

See the :ref:`custodian` documentation for more information on how custodians interact with the IssuingEntity contract.

.. method:: IssuingEntity.addCustodian(address _custodian)

    Approves a custodian contract to send and receive tokens associated with the issuer.

    Once a custodian is approved, they can be restricted with ``IssuingEntity.setInvestorRestriction``.

    .. warning:: Custodians may facilitate off-chain transfers of ownership that bypass on-chain compliance checks. It is imperative this approval only be given to known, trusted entities who have deployed a verified, audited custodian contract.

.. method:: IssuingEntity.setBeneficialOwners(bytes32 _custID, bytes32[] _id, bool _add)

    Modifies the list of beneficial owners associated with the custodian.

    * ``_custID``: Custodian ID
    * ``_id``: Array of investor IDs
    * ``_add``: Permission bool

    This can only be called via the custodian's contract, or by the issuer. An issuer should only use this method in a case where a custodian has been found to be acting in bad-faith.


Setting Investor Limits
=======================

Issuers can define investor limits globally, by country, by investor rating, or by a combination thereof. These limits are common across all tokens associated to the issuer.

Investor counts and limits are stored in uint32[8] arrays. The first entry in each array is the sum of all the remaining entries. The remaining entries correspond to the count or limit for each investor rating. In most (if not all) countries there will be less than 7 types of investor accreditation ratings, and so the upper range of these arrays will be empty. Setting an investor limit to 0 means no limit is imposed.

The issuer must explicitely approve each country from which investors are allowed to purchase tokens.

It is possible for an issuer to set a limit that is lower than the current investor count. When a limit is met or exceeded existing investors are still able to receive tokens, but new investors are blocked.

.. method:: IssuingEntity.setCountry(uint16 _country, bool _allowed, uint8 _minRating, uint32[8] _limits)

    Approve or restrict a country, and/or modify it's minimum investor rating and investor limits.

    * ``_country``: The code of the country to modify
    * ``_allowed``: Permission bool
    * ``_minRating``: The minimum rating required for an investor in this country to hold tokens. Cannot be zero.
    * ``_limits``: A uint32[8] array of investor limits for this country.

.. method:: IssuingEntity.setCountries(uint16[] _country, bool _allowed, uint8[] _minRating, uint32[] _limit)

    Approve or restrict many countries at once.

    * ``_countries``: An array of country codes to modify
    * ``_allowed``: Permission bool
    * ``_minRating``: Array of minimum investor ratings for each country.
    * ``_limits``: Array of total investor limits for each country.

    Each array must be the same length. The function will iterate through them at the same time: ``_countries[0]`` will require rating ``_minRating[0]`` and have a total investor limit of ``_limits[0]``.

    This method is useful when approving many countries that do not require specific limits based on investor ratings. When you require specific limits for each rating, use ``IssuingEntity.setCountry``.

.. method:: IssuingEntity.setInvestorLimits(uint32[8] _limits)

    Sets total investor limits, irrespective of country.

.. method:: IssuingEntity.getInvestorCounts()

    Returns the sum total investor counts and limits for all countries and issuances related to this contract.

.. method:: IssuingEntity.getCountry(uint16 _country)

    Returns the minimum rating, investor counts and investor limits for a given country.

Document Verification
=====================

.. method:: IssuingEntity.setDocumentHash(string _documentID, bytes32 _hash)

    Creates an on-chain record of the hash of a legal document.

    Once a hash is recorded, the issuer can distrubute the document electronically and investors can verify the authenticity by generating the hash themselves and comparing it to the blockchain record.

.. method:: IssuingEntity.getDocumentHash(string _documentID)

    Returns a recorded document hash.

Modules
=======

The issuer may use these methods to attach or detach modules to this contract or any associated token contract.

See the :ref:`modules` documentation for more information.

.. method:: IssuingEntity.attachModule(address _target, address _module)

    Attaches a module.

    * ``_target``: The address of the contract to associate the module to.
    * ``_module``: The address of the module contract.

.. method:: IssuingEntity.detachModule(address _target, address _module)

    Detaches a module.

.. method:: IssuingEntity.isActiveModule(address _module)

    Returns true if a module is currently active on the contract. Modules that are active on a token will return false.

Integration
===========
