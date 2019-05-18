.. _issuing-entity:

#############
IssuingEntity
#############

IssuingEntity contracts hold shared compliance logic for all security tokens created by a single issuer. They are the central contract that an issuer uses to connect and interact with registrars, tokens and custodians.

Each issuer contract includes standard SFT protocol multis-gi functionality. See :ref:`multisig` for detailed information on this component.

This documentation only explains contract methods that are meant to be accessed directly. External methods that will revert unless called through another contract, such as a token or module, are not included.

It may be useful to also view the `IsssuingEntity.sol <https://github.com/HyperLink-Technology/SFT-Protocol/blob/master/contracts/IssuingEntity.sol>`__ source code while reading this document.

Deployment
==========

The constructor declares the owner as per standard :ref:`multisig`.

.. method:: IssuingEntity.constructor(address[] _owners, uint32 _threshold)

    * ``_owners``: One or more addresses to associate with the contract owner. The address deploying the contract is not implicitly included within the owner list.
    * ``_threshold``: The number of calls required for the owner to perform a multi-sig action.

    The ID of the owner is generated as a keccak of the contract address and available from the public getter ``ownerID``.

    .. code-block:: python

        >>> issuer = accounts[0].deploy(IssuingEntity, [accounts[0], accounts[1]], 1)

        Transaction sent: 0xb37d8d16b266796e64fde6a4e9813ae0673dddaeb63022d91c706612ee741972
        IssuingEntity.constructor confirmed - block: 1   gas used: 6473451 (80.92%)
        IssuingEntity deployed at: 0xa79269260195879dBA8CEFF2767B7F2B5F2a54D8
        <IssuingEntity Contract object '0xa79269260195879dBA8CEFF2767B7F2B5F2a54D8'>

Public Constants
================

The following public variables cannot be changed after contract deployment.

.. method:: IssuingEntity.ownerID()

    The bytes32 ID hash of the issuer.

    .. code-block:: python

        >>> issuer.ownerID()
        0xce1e12589ad8fb3eed11af5b9ef8788c25b574d4073d23c871e003021400c429

Tokens, Registrars, Custodians, Governance
==========================================

The ``IssuingEntity`` contract is a center point through which other contracts are linked. Each contract must be associated to it before it will function properly.

* :ref:`security-token` contracts must be associated before tokens can be transferred, so that the issuer contract can accurately track investor counts.
* :ref:`kyc` contracts must be associated to provide KYC data on investors before they can receive or send tokens.
* :ref:`custodian` contracts must be approved in order to send or receive tokens from investors.
* A :ref:`governance` contract may optionally be associated. Once attached, it requires the issuer to receive on-chain approval before creating or minting additional tokens.

Associating Contracts
---------------------

.. method:: IssuingEntity.addToken(address _token)

    Associates a new :ref:`security-token` contract with the issuer contract.

    Once added, the token can be restricted with ``IssuingEntity.setTokenRestriction``.

    If a :ref:`governance` module has been set, it must provide approval whenever this method is called.

    Emits the ``TokenAdded`` event.

    .. code-block:: python

        >>> issuer.addToken(SecurityToken[0], {'from': accounts[0]})

        Transaction sent: 0x8e93cd6b85d1e993755e9fe31eb14ce600706eaf98d606156447d8e431db5db9
        IssuingEntity.addToken confirmed - block: 5   gas used: 61630 (0.77%)
        <Transaction object '0x8e93cd6b85d1e993755e9fe31eb14ce600706eaf98d606156447d8e431db5db9'>

.. method:: IssuingEntity.setRegistrar(address _registrar, bool _permitted)

    Associates or removes a :ref:`kyc` contract.

    Before a transfer is completed, each associated registrar is called to check which IDs are associated to the transfer addresses.

    The address => ID association is stored within IssuingEntity. If a registrar is later removed it is impossible for another registrar to return a different ID for the address.

    When a registrar is removed, any investors that were identified through it will be unable to send or receive tokens until they are identified through another associated registrar. Transfer attempts will revert with the message "Registrar restricted".

    Emits the ``RegistrarSet`` event.

    .. code-block:: python

        >>> issuer.setRegistrar(KYCRegistrar[0], True, {'from': accounts[0]})

        Transaction sent: 0x606326c8b2b8f1541c333ef5a5cd44592efb50530c6326e260e728095b3ec2bd
        IssuingEntity.setRegistrar confirmed - block: 3   gas used: 61246 (0.77%)
        <Transaction object '0x606326c8b2b8f1541c333ef5a5cd44592efb50530c6326e260e728095b3ec2bd'>

.. method:: IssuingEntity.addCustodian(address _custodian)

    Approves a :ref:`custodian` contract to send and receive tokens associated with the issuer.

    Once a custodian has been added, they can be restricted with ``IssuingEntity.setEntityRestriction``.

    Emits the ``CustodianAdded`` event.

    .. code-block:: python

        >>> issuer.addCustodian(OwnedCustodian[0])

        Transaction sent: 0xbae451ce98691dc37dad6a67d8daf410a3eeebf34b59ab60eaeef7c3f3a2654c
        IssuingEntity.addCustodian confirmed - block: 25   gas used: 78510 (0.98%)
        <Transaction object '0xbae451ce98691dc37dad6a67d8daf410a3eeebf34b59ab60eaeef7c3f3a2654c'>

.. method:: IssuingEntity.setGovernance(address _governance)

    Sets the active :ref:`Governance` contract.

    Setting the address to ``0x00`` disables governance functionality.

    .. code-block:: python

        >>> issuer.setGovernance(GovernanceMinimal[0])

        Transaction sent: 0x8e93cd6b85d1e993755e9fe31eb14ce600706eaf98d606156447d8e431db5db9
        IssuingEntity.addCustodian confirmed - block: 26   gas used: 63182 (0.98%)
        <Transaction object '0x8e93cd6b85d1e993755e9fe31eb14ce600706eaf98d606156447d8e431db5db9'>

Setting Restrictions
--------------------

Transfer restrictions can be applied at varying levels.

.. method:: IssuingEntity.setEntityRestriction(bytes32 _id, bool _permitted)

    Retricts or permits an investor or custodian from transferring tokens, based on their ID.

    This can only be used to block an investor that would otherwise be able to hold the tokens. It cannot be used to whitelist investors who are not listed in an associated registrar. When an investor is restricted, the issuer is still able to transfer tokens from their addresses.

    Emits the ``EntityRestriction`` event.

    .. code-block:: python

        >>> SecurityToken[0].transfer(accounts[2], 100, {'from': accounts[1]})

        Transaction sent: 0x89bf6113bd5ccf9917d0749776fa4bed986d519d66221973def33c0190a2e6d2
        SecurityToken.transfer confirmed - block: 21   gas used: 192387 (2.40%)
        >>> issuer.setEntityRestriction(id_, False)

        Transaction sent: 0xfc4dabf2c48b4502ab4a9d3edbfc0ea792e715069ede0f8b455697df180bfc9f
        IssuingEntity.setEntityRestriction confirmed - block: 22   gas used: 39978 (0.50%)
        >>> SecurityToken[0].transfer(accounts[2], 100, {'from': accounts[1]})
        File "contract.py", line 277, in call
          raise VirtualMachineError(e)
        VirtualMachineError: VM Exception while processing transaction: revert Sender restricted: Issuer

.. method:: IssuingEntity.setTokenRestriction(address _token, bool _permitted)

    Restricts or permits transfers of a token. When a token is restricted, only the issuer may perform transfers.

    Emits the ``TokenRestriction`` event.

    .. code-block:: python

        >>> issuer.setTokenRestriction(SecurityToken[0], False, {'from': accounts[0]})

        Transaction sent: 0xfe60d18d0315278bdd1cfd0896a040cdadb63ada255685737908672c0cd10cee
        IssuingEntity.setTokenRestriction confirmed - block: 13   gas used: 40369 (0.50%)
        <Transaction object '0xfe60d18d0315278bdd1cfd0896a040cdadb63ada255685737908672c0cd10cee'>

.. method:: IssuingEntity.setGlobalRestriction(bool _permitted)

    Restricts or permits transfers of all associated tokens. Modifying the global restriction does not affect individual token restrictions - i.e. you cannot call this method to remove restrictions that were set with ``IssuingEntity.setTokenRestriction``.

    Emits the ``GlobalRestriction`` event.

    .. code-block:: python

        >>> issuer.setGlobalRestriction(False, {'from': accounts[0]})

        Transaction sent: 0xc03ac4c6d36e971f980297e365f30752ac5097e391213c59fd52544829a87479
        IssuingEntity.setGlobalRestriction confirmed - block: 14   gas used: 53384 (0.67%)
        <Transaction object '0xc03ac4c6d36e971f980297e365f30752ac5097e391213c59fd52544829a87479'>

Getters
-------

.. method:: IssuingEntity.isActiveToken(address _token)

    Returns a boolean indicating if the given address is a token contract that is associated with the ``IssuingEntity`` not currently restricted.

    .. code-block:: python

        >>> issuer.isActiveToken(SecurityToken[0])
        True
        >>> issuer.isActiveToken(accounts[2])
        False

.. method:: IssuingEntity.governance()

    Returns the address of the associated ``Governance`` contract. If none is set, returns ``0x00``.

    .. code-block:: python

        >>> issuer.governance()
        "0x14b0Ed2a7C4cC60DD8F676AE44D0831d3c9b2a9E"

Investors
=========

Investors must be identified by a :ref:`kyc` before they can send or receive tokens. This identity data is then used to apply further checks against investor limits and accreditation requirements.

Getters
-------

The ``IssuingEntity`` contract contains several public getter methods for querying information relating to investors.

.. method:: IssuingEntity.isRegisteredInvestor(address _addr)

    Check if an address belongs to a registered investor and return a bool. Returns ``false`` if the address is not registered.

    .. code-block:: python

        >>> issuer.isRegisteredInvestor(accoounts[2])
        True
        >>> issuer.isRegisteredInvestor(accoounts[9])
        False

.. method:: IssuingEntity.getID(address _addr)

    Returns the investor ID associated with an address. If the address is not saved in the contract, this call will query associated registrars. If the ID cannot be found the call will revert.

    .. code-block:: python

        >>> issuer.getID(accounts[1])
        0x8be1198d7f1848ebeddb3f807146ce7d26e63d3b6715f27697428ddb52db9b63
        >>> issuer.getID(accounts[9])
        File "contract.py", line 277, in call
          raise VirtualMachineError(e)
        VirtualMachineError: VM Exception while processing transaction: revert Address not registered

.. method:: IssuingEntity.getInvestorRegistrar(bytes32 _id)

    Returns the registrar address associated with an investor ID. If the investor ID is not saved in the ``IssuingEntity`` contract storage, this call will return ``0x00``.

    Note that an investor's ID is only saved in the contract after a successful token transfer. Even if the investor's ID is known via an associated registrar, if they have never received tokens the call to ``getInvestorRegistrar`` will return an empty value.

    .. code-block:: python

        >>> id_ = issuer.getID(accounts[1])
        0x8be1198d7f1848ebeddb3f807146ce7d26e63d3b6715f27697428ddb52db9b63
        >>> issuer.getInvestorRegistrar(id_)
        0xa79269260195879dBA8CEFF2767B7F2B5F2a54D8

Investor Limits
===============

Issuers can define investor limits globally, by country, by investor rating, or by a combination thereof. These limits are shared across all tokens associated to the issuer.

Investor counts and limits are stored in uint32[8] arrays. The first entry in each array is the sum of all the remaining entries. The remaining entries correspond to the count or limit for each investor rating. In most (if not all) countries there will be less than 7 types of investor accreditation ratings, and so the upper range of these arrays will be empty. Setting an investor limit to 0 means no limit is imposed.

The issuer must explicitely approve each country from which investors are allowed to purchase tokens.

It is possible for an issuer to set a limit that is lower than the current investor count. When a limit is met or exceeded existing investors are still able to receive tokens, but new investors are blocked.

Setters
-------

.. method:: IssuingEntity.setCountry(uint16 _country, bool _permitted, uint8 _minRating, uint32[8] _limits)

    Approve or restrict a country, and/or modify it's minimum investor rating and investor limits.

    * ``_country``: The code of the country to modify
    * ``_permitted``: Permission bool
    * ``_minRating``: The minimum rating required for an investor in this country to hold tokens. Cannot be zero.
    * ``_limits``: A uint32[8] array of investor limits for this country.

    Emits the ``CountryModified`` event.

    .. code-block:: python

        >>> issuer.setCountry(784, True, 1, [100, 0, 0, 0, 0, 0, 0, 0], {'from': accounts[0]})

        Transaction sent: 0x96f9a7e12e898fbd2fb6c7593a7ae82c4eea087c508929e616f86e98ae9b0db6
        IssuingEntity.setCountry confirmed - block: 26   gas used: 116709 (1.46%)
        <Transaction object '0x96f9a7e12e898fbd2fb6c7593a7ae82c4eea087c508929e616f86e98ae9b0db6'>

.. method:: IssuingEntity.setCountries(uint16[] _country, bool _permitted, uint8[] _minRating, uint32[] _limit)

    Approve or restrict many countries at once.

    * ``_countries``: An array of country codes to modify
    * ``_permitted``: Permission bool
    * ``_minRating``: Array of minimum investor ratings for each country.
    * ``_limits``: Array of total investor limits for each country.

    Each array must be the same length. The function will iterate through them at the same time: ``_countries[0]`` will require rating ``_minRating[0]`` and have a total investor limit of ``_limits[0]``.

    This method is useful when approving many countries that do not require specific limits based on investor ratings. When you require specific limits for each rating, use ``IssuingEntity.setCountry``.

    Emits the ``CountryModified`` event once for each country that is modified.

    .. code-block:: python

        >>> issuer.setCountries([784],[1],[0], {'from': accounts[0]})

        Transaction sent: 0x7299b96013acb4661f4b7f05016c0de6726d2337032740aa29f5407cdabde0c3
        IssuingEntity.setCountries confirmed - block: 6   gas used: 72379 (0.90%)
        <Transaction object '0x7299b96013acb4661f4b7f05016c0de6726d2337032740aa29f5407cdabde0c3'>

.. method:: IssuingEntity.setInvestorLimits(uint32[8] _limits)

    Sets total investor limits, irrespective of country.

    Emits the ``InvestorLimitsSet`` event.

    .. code-block:: python

        >>> issuer.setInvestorLimits([2000, 500, 2000, 0, 0, 0, 0, 0], {'from': accounts[0]})

        Transaction sent: 0xbeda494b5fb741ae659b866b9f5eca26b9add249ae75dc651a7944281e2ae4eb
        IssuingEntity.setInvestorLimits confirmed - block: 27   gas used: 94926 (1.19%)
        <Transaction object '0xbeda494b5fb741ae659b866b9f5eca26b9add249ae75dc651a7944281e2ae4eb'>

Getters
-------

.. method:: IssuingEntity.getInvestorCounts()

    Returns the sum total investor counts and limits for all countries and issuances related to this contract.

    .. code-block:: python

        >>> issuer.getInvestorCounts().dict()
        {
            '_counts': ((1, 0, 1, 0, 0, 0, 0, 0),
            '_limits': (2000, 500, 2000, 0, 0, 0, 0, 0))
        }

.. method:: IssuingEntity.getCountry(uint16 _country)

    Returns the minimum rating, investor counts and investor limits for a given country. Countries that have not been set will return all zero values. The easiest way to verify if a country has been set is to check if ``_minRating > 0``.

    .. code-block:: python

        >>> issuer.getCountry(784).dict()
        {
            '_count': (0, 0, 0, 0, 0, 0, 0, 0),
            '_limit': (100, 0, 0, 0, 0, 0, 0, 0),
            '_minRating': 1
        }


Document Verification
=====================

.. method:: IssuingEntity.getDocumentHash(string _documentID)

    Returns a recorded document hash. If no hash is recorded, it will return ``0x00``.

    See `Document Verification`_.

    .. code-block:: python

        >>> issuer.getDocumentHash("Shareholder Agreement")
        "0xbeda494b5fb741ae659b866b9f5eca26b9add249ae75dc651a7944281e2ae4eb"
        >>> issuer..getDocumentHash("Unknown Document")
        0x0000000000000000000000000000000000000000000000000000000000000000

.. method:: IssuingEntity.setDocumentHash(string _documentID, bytes32 _hash)

    Creates an on-chain record of the hash of a legal document.

    Once a hash is recorded, the issuer can distrubute the document electronically and investors can verify the authenticity by generating the hash themselves and comparing it to the blockchain record.

    Emits the ``NewDocumentHash`` event.

    .. code-block:: python

        >>> issuer.setDocumentHash("Shareholder Agreement", "0xbeda494b5fb741ae659b866b9f5eca26b9add249ae75dc651a7944281e2ae4eb", {'from': accounts[0]})

        Transaction sent: 0x7299b96013acb4661f4b7f05016c0de6726d2337032740aa29f5407cdabde0c3
        IssuingEntity.setDocumentHash confirmed - block: 6   gas used: 72379 (0.90%)
        <Transaction object '0x7299b96013acb4661f4b7f05016c0de6726d2337032740aa29f5407cdabde0c3'>



.. _issuing-entity-modules:

Modules
=======

Modules for token contracts are attached and detached through the associated ``IssuingEntity``. This contract itself is not directly modular, however any module that declares it as the owner may be attached to all the associated token contracts.

See the :ref:`modules` documentation for more information on module functionality and development.

.. _issuing-entity-modules-attach-detach:

Attaching and Detaching
-----------------------

.. method:: IssuingEntity.attachModule(address _target, address _module)

    Attaches a module.

    * ``_target``: The address of the contract to associate the module to.
    * ``_module``: The address of the module contract.

    .. code-block:: python

        >>> module = DividendModule.deploy(accounts[0], SecurityToken[0], issuer, 1600000000)

        Transaction sent: 0x1b1e7a09e7731fcb724a6586e3cf71c07221db009e89445c33e07cc8e18e74d1
        DividendModule.constructor confirmed - block: 13   gas used: 1756759 (21.96%)
        DividendModule deployed at: 0x3BcC6Ad6CFbB1997eb9DA056946FC38a6b5E270D
        <DividendModule Contract object '0x3BcC6Ad6CFbB1997eb9DA056946FC38a6b5E270D'>
        >>>
        >>> issuer.attachModule(SecurityToken[0], module, {'from': accounts[0]})

        Transaction sent: 0x7123091c968dbe0c279aa6850c668534aef327972a08d65b67779108cbaa9b45
        IssuingEntity.attachModule confirmed - block: 14   gas used: 212332 (2.65%)
        <Transaction object '0x7123091c968dbe0c279aa6850c668534aef327972a08d65b67779108cbaa9b45'>

.. method:: IssuingEntity.detachModule(address _target, address _module)

    Detaches a module.

    .. code-block:: python

        >>> issuer.detachModule(SecurityToken[0], module, {'from': accounts[0]})

        Transaction sent: 0xe1539492053b91ffb05dec6da6f73a02f0b3e44fcec707acf911d37922b65699
        IssuingEntity.detachModule confirmed - block: 15   gas used: 28323 (0.35%)
        <Transaction object '0xe1539492053b91ffb05dec6da6f73a02f0b3e44fcec707acf911d37922b65699'>

Events
======

The ``IssuingEntity`` contract includes the following events.

.. method:: IssuingEntity.TokenAdded(address indexed token)

    Emitted after a new token contract has been associated via ``IssuingEntity.addToken``.

.. method:: IssuingEntity.RegistrarSet(address indexed registrar, bool permitted)

    Emitted by ``IssuingEntity.setRegistrar`` when a new KYC registrar contract is added, or an existing registrar is restricted or permitted.

.. method:: IssuingEntity.CustodianAdded(address indexed custodian)

    Emitted when a new custodian contract is approved via ``IssuingEntity.addCustodian``.

.. method:: IssuingEntity.EntityRestriction(bytes32 indexed id, bool permitted)

    Emitted whenever an investor or custodian has a restriction set or removed with ``IssuingEntity.setEntityRestriction``.

.. method:: IssuingEntity.TokenRestriction(address indexed token, bool permitted)

    Emitted when a token restriction is set or removed via ``IssuingEntity.setTokenRestriction``.

.. method:: IssuingEntity.GlobalRestriction(bool permitted)

    Emitted when a global restriction is set with ``IssuingEntity.setGlobalRestriction``.

.. method:: IssuingEntity.InvestorLimitsSet(uint32[8] limits)

    Emitted when global investor limits are modified via ``IssuingEntity.setInvestorLimits``.

.. method:: IssuingEntity.CountryModified(uint16 indexed country, bool permitted, uint8 minrating, uint32[8] limits)

    Emitted whenever country specific limits are set via ``IssuingEntity.setCountry`` or ``IssuingEntity.SetCountries``.

.. method:: IssuingEntity.NewDocumentHash(string indexed document, bytes32 documentHash)

    Emitted when a new document hash is saved with ``IssuingEntity.setDocumentHash``.
