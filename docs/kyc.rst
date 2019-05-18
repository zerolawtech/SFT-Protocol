.. _kyc:

###
KYC
###

KYC registry contracts are whitelists that hold information on the identity, region, and rating of investors. Depending on the use case there are two implementations:

* `KYCIssuer.sol <https://github.com/HyperLink-Technology/SFT-Protocol/blob/master/contracts/KYCIssuer.sol>`__ is a streamlined whitelist contract designed for use with a single ``IssuingEntity``.
* `KYCRegistrar.sol <https://github.com/HyperLink-Technology/SFT-Protocol/blob/master/contracts/KYCRegistrar.sol>`__ is a more robust implementation. It is maintainable by one or more entities across many jurisdictions, and designed to supply KYC data to many ``IssuingEntity`` contracts.

Both contracts are derived from a common base `KYC.sol <https://github.com/HyperLink-Technology/SFT-Protocol/blob/master/contracts/bases/KYC.sol>`__ that defines standard getter functions and events.

Contract authorities associate addresses to ID hashes that denote the identity of the investor who controls the address. More than one address may be associated to the same hash. Anyone can call ``KYCBase.getID`` to see which hash is associated to an address, and then using this ID call functions to query information about the investor's region and accreditation rating.

Deployment
==========

Deployment varies depending on the type of registrar contract.

KYCIssuer
---------

The address of the issuer is declared during deployment. The identity of the contract owner and authorities are determined by calls to this contract.

.. method:: KYCIssuer.constructor(address _issuer)

    * ``_issuer``: The address of the ``IssuingEntity`` contract to associate this contract with.

    .. code-block:: python

        >>> issuer = IssuingEntity[0]
        <IssuingEntity Contract object '0x40b49Ad1B8D6A8Df6cEdB56081D51b69e6569e06'>
        >>> kyc = accounts[0].deploy(KYCIssuer, issuer)

        Transaction sent: 0x98f595f75535df670d0c83b247bb471189938f0f57385fa1c7d3c6621748c703
        KYCIssuer.constructor confirmed - block: 2   gas used: 1645437 (20.57%)
        KYCIssuer deployed at: 0xa79269260195879dBA8CEFF2767B7F2B5F2a54D8
        <KYCIssuer Contract object '0xa79269260195879dBA8CEFF2767B7F2B5F2a54D8'>
        >>> kyc.issuer()
        '0x40b49Ad1B8D6A8Df6cEdB56081D51b69e6569e06'

KYCRegistrar
------------

The owner is declared during deployment. The owner is the highest contract authority, impossible to restrict and the only entity capable of creating or restricting other authorities on the contract.

.. method:: KYCRegistrar.constructor(address[] _owners, uint32 _threshold)

    * ``_owners``: One or more addresses to associate with the contract owner. The address deploying the contract is not implicitly included within the owner list.
    * ``_threshold``: The number of calls required for the owner to perform a multi-sig action. Cannot exceed the length of ``_owners``.

    .. code-block:: python

        >>> kyc = accounts[0].deploy(KYCRegistrar, [accounts[0]], 1)

        Transaction sent: 0xd10264c1445aad4e9dc84e04615936624e0b96596fec2097bebc83f9d3e69664
        KYCRegistrar.constructor confirmed - block: 2   gas used: 2853810 (35.67%)
        KYCRegistrar deployed at: 0x40b49Ad1B8D6A8Df6cEdB56081D51b69e6569e06
        <KYCRegistrar Contract object '0x40b49Ad1B8D6A8Df6cEdB56081D51b69e6569e06'>


Contract Owners and Authorities
===============================

KYCIssuer
---------

``KYCIssuer`` retrieves authority permissions and derives multisig functionality from the associated ``IssuingEntity`` contract. The owner of the issuer contract may call any method within the registrar. Authorities may call any method that they have been explicitely permitted to call.

See the :ref:`multisig` documentation for information on this aspect of the contract's functionality.

.. _kyc-registrar:

KYCRegistrar
------------

The owner is declared during deployment. The owner is the highest contract authority, impossible to restrict and the only entity capable of creating or restricting other authorities on the contract.

Authorities are known, trusted entities that are permitted to add, modify, or restrict investors within the registrar. Authorities are assigned a unique ID and associated with one or more addresses. They do not require explicit permission to call any contract functions. However, they may only add, modify or restrict investors in countries that they have been approved to operate in.

``KYCRegistrar`` implements a variation of the standard :ref:`multisig` functionality used in other contracts within the protocol. This section assumes familiarity with the standard multi-sig implementation, and will only highlight the differences.

Adding Authorities
******************

.. method:: KYCRegistrar.addAuthority(address[] _addr, uint16[] _countries, uint32 _threshold)

    Creates a new authority.

    * ``_owners``: One or more addresses to associate with the authority
    * ``_countries``: Countries that the authority is approved to act in
    * ``_threshold``: The number of calls required for the authority to perform a multi-sig action. Cannot exceed the length of ``_owners``

    Once an authority has been designated they may use ``KYCRegistrar.registerAddresses`` or ``KYCRegistrar.restrictAddresses`` to modify their associated addresses.

    Emits the ``NewAuthority`` event.

    .. code-block:: python

        >>> kyc.addAuthority([accounts[1], accounts[2]], [4, 11, 77, 784], 1, {'from': accounts[0]})

        Transaction sent: 0x6085f4c75f12c4bed01c541d9a7e1d8f7e1ffc85247b5582459cbdd99fa1b51b
        KYCRegistrar.addAuthority confirmed - block: 2   gas used: 157356 (1.97%)
        <Transaction object '0x6085f4c75f12c4bed01c541d9a7e1d8f7e1ffc85247b5582459cbdd99fa1b51b'>
        >>> id_ = kyc.getAuthorityID(accounts[1])
        0x7b809759765e66e1999ae953ef432bec3472905be1588b398563de2912cd7d01


Modifying Authorities
*********************

.. method:: KYCRegistrar.setAuthorityCountries(bytes32 _id, uint16[] _countries, bool _permitted)

    Modifies the country permissions for an authority.

    .. code-block:: python

        >>> kyc.isApprovedAuthority(accounts[1], 4)
        True
        >>> kyc.setAuthorityCountries(id_, [4, 11], False, {'from': accounts[0]})

        Transaction sent: 0x60e9cc4c79bf08fd2929d33039f24278d63b28c91269ff79dc752f06a2c29e2a
        KYCRegistrar.setAuthorityCountries confirmed - block: 3   gas used: 46196 (0.58%)
        <Transaction object '0x60e9cc4c79bf08fd2929d33039f24278d63b28c91269ff79dc752f06a2c29e2a'>
        >>> kyc.isApprovedAuthority(accounts[1], 4)
        False

.. method:: KYCRegistrar.setAuthorityThreshold(bytes32 _id, uint32 _threshold)

    Modifies the multisig threshold requirement for an authority. Can be called by any authority to modify their own threshold, or by the owner to modify the threshold for anyone.

    You cannot set the threshold higher than the number of associated, unrestricted addresses for the authority.

    .. code-block:: python

        >>> kyc.setAuthorityThreshold(id_, 2, {'from': accounts[0]})

        Transaction sent: 0xe253c5acb5f0896ebdc92090c23bcec8baab0e23abe513ae6119caf51522e425
        KYCRegistrar.setAuthorityThreshold confirmed - block: 4   gas used: 39535 (0.49%)
        <Transaction object '0xe253c5acb5f0896ebdc92090c23bcec8baab0e23abe513ae6119caf51522e425'>
        >>>
        >>> kyc.setAuthorityThreshold(id_, 3, {'from': accounts[0]})
        File "contract.py", line 277, in call
          raise VirtualMachineError(e)
        VirtualMachineError: VM Exception while processing transaction: revert

.. method:: KYCRegistrar.setAuthorityRestriction(bytes32 _id, bool _permitted)

    Modifies the permitted state of an authority.

    If an authority has been compromised or found to be acting in bad faith, the owner may apply a broad restriction upon them with this method. This will also restrict every investor that was approved by the authority.

    A list of investors that were approved by the restricted authority can be obtained by looking at ``NewInvestor`` and ``UpdatedInvestor`` events. Once the KYC/AML of these investors has been re-verified, the restriction upon them may be removed by calling either ``KYCRegistrar.updateInvestor`` or ``KYCRegistrar.setInvestorAuthority`` to change which authority they are associated with.

    Emits the ``AuthorityRestriction`` event.

    .. code-block:: python

        >>> kyc.isApprovedAuthority(accounts[1], 784)
        True
        >>> kyc.setAuthorityRestriction(id_, False)

        Transaction sent: 0xeb3456fae407fb9bd673075369903769326c9f8699b313feb46e92f7f199c72e
        KYCRegistrar.setAuthorityRestriction confirmed - block: 10   gas used: 40713 (28.93%)
        <Transaction object '0xeb3456fae407fb9bd673075369903769326c9f8699b313feb46e92f7f199c72e'>
        >>> kyc.isApprovedAuthority(accounts[1], 784)
        False


Getters
*******

The following getter methods are available to query information about contract authorities:

.. method:: KYCRegistrar.isApprovedAuthority(address _addr, uint16 _country)

    Checks whether an authority is approved to add or modify investors from a given country.  Returns ``false`` if the authority is not permitted.

    .. code-block:: python

        >>> kyc.isApprovedAuthority(accounts[1], 784)
        True

.. method:: KYCRegistrar.getAuthorityID(address _addr)

    Given an address, returns the ID hash of the associated authority.  If the address is not associated with an authority the call will revert.

    .. code-block:: python

        >>> kyc.getAuthorityID(accounts[1])
        0x7b809759765e66e1999ae953ef432bec3472905be1588b398563de2912cd7d01
        >>> kyc.getAuthorityID(accounts[3])
        File "contract.py", line 277, in call
          raise VirtualMachineError(e)
        VirtualMachineError: VM Exception while processing transaction: revert

Working with Investors
======================

Investors are natural persons or legal entities who have passed KYC/AML checks and are approved to send and receive security tokens.

Each investor is assigned a unique ID and is associated with one or more addresses. They are also assigned an expiration time for their rating. This is useful in jurisdictions where accreditation status requires periodic reconfirmation.

See the :ref:`data-standards` documentation for detailed information on how to generate and format investor information for use with registrar contracts.

Adding Investors
----------------

.. method:: KYCBase.generateID(string _idString)

    Returns the keccak hash of the supplied string. Can be used by an authority to generate an investor ID hash from their KYC information.

    .. code-block:: python

        >>> id_ = kyc.generateID("JOHNDOE010119701234567890")
        0xd3e7532ecb2c15babc9a5ac8e65f9d96b7030ab7e5dc9fffaa00ac15c0937be4

.. method:: KYCBase.addInvestor(bytes32 _id, uint16 _country, bytes3 _region, uint8 _rating, uint40 _expires, address[] _addr)

    Adds an investor to the registrar.

    * ``_id``: Investor's bytes32 ID hash
    * ``_country``: Investor country code
    * ``_region``: Investor region code
    * ``_rating``: Investor rating code
    * ``_expires``: The epoch time that the investor rating is valid until
    * ``_addr```: One or more addresses to associate with the investor

    Similar to authorities, addresses associated with investors can be modified by calls to ``KYCRegistrar.registerAddresses`` or ``KYCRegistrar.restrictAddresses``.

    Emits the ``NewInvestor`` event.

    .. code-block:: python

        >>> kyc.addInvestor(id_, 784, "0x465500", 1, 9999999999, (accounts[3],), {'from': accounts[0]})

        Transaction sent: 0x47581e5b276298427f6a520353622b96cdecb29dff7269f03d7c957435398ebd
        KYCRegistrar.addInvestor confirmed - block: 3   gas used: 120707 (1.51%)
        <Transaction object '0x47581e5b276298427f6a520353622b96cdecb29dff7269f03d7c957435398ebd'>

Modifying Investors
-------------------

.. method:: KYCBase.updateInvestor(bytes32 _id, bytes3 _region, uint8 _rating, uint40 _expires)

    Updates information on an existing investor.

    Due to the way that the investor ID is generated, it is not possible to modify the country that an investor is associated with. An investor who changes their legal country of residence will have to resubmit KYC, be assigned a new ID, and transfer their tokens to a different address.

    Emits the ``UpdatedInvestor`` event.

    .. code-block:: python

        >>> kyc.updateInvestor(id_, "0x465500", 2, 1600000000, {'from': accounts[0]})

        Transaction sent: 0xacfb17b530d2b565ea6016ab9b50051edb85e92e5ec6d2d85b1ac1708f897949
        KYCRegistrar.updateInvestor confirmed - block: 4   gas used: 50443 (0.63%)
        <Transaction object '0xacfb17b530d2b565ea6016ab9b50051edb85e92e5ec6d2d85b1ac1708f897949'>

.. method:: KYCBase.setInvestorRestriction(bytes32 _id, bool _permitted)

    Modifies the restricted status of an investor.  An investor who is restricted will be unable to send or receive tokens.

    Emits the ``InvestorRestriction`` event.

    .. code-block:: python

        >>> kyc.setInvestorRestriction(id_, False, {'from': accounts[0]})

        Transaction sent: 0x175982346d2f00a25f00a69701cda6fa311d60ade94d801267f51eefa86dc49e
        KYCRegistrar.setInvestorRestriction confirmed - block: 5   gas used: 41825 (0.52%)
        <Transaction object '0x175982346d2f00a25f00a69701cda6fa311d60ade94d801267f51eefa86dc49e'>

KYCRegistrar
************

The following method is only available in ``KYCRegistrar``.

.. method:: KYCRegistrar.setInvestorAuthority(bytes32[] _id, bytes32 _authID)

    Modifies the authority that is associated with one or more investors.

    This method is only callable by the owner. It can be used after an authority is restricted, to remove the implied restriction upon investors that were added by that authority.

    .. code-block:: python

        >>> auth_id = kyc.getAuthorityID(accounts[1])
        0x7b809759765e66e1999ae953ef432bec3472905be1588b398563de2912cd7d01
        >>> kyc.setInvestorAuthority([id_], auth_id, {'from': accounts[0]})

        Transaction sent: 0x175982346d2f00a25f00a69701cda6fa311d60ade94d801267f51eefa86dc49e
        KYCRegistrar.setInvestorRestriction confirmed - block: 5   gas used: 41825 (0.52%)
        <Transaction object '0x175982346d2f00a25f00a69701cda6fa311d60ade94d801267f51eefa86dc49e'>

Adding and Restricting Addresses
================================

Each authority and investor has one or more addresses associated to them. Once an address has been assigned to an ID, this association may never be removed. If an association were removed it would then be possible to assign that same address to a different investor. This could be used to circumvent transfer restrictions on tokens, allowing for non-compliant token ownership.

In situations of a lost or compromised private key the address may instead be flagged as restricted. In this case any tokens in the restricted address can be retrieved using another associated, unrestricted address.

.. method:: KYCBase.registerAddresses(bytes32 _id, address[] _addr)

    Associates one or more addresses to an ID, or removes restrictions imposed upon already associated addresses.

    In ``KYCRegistrar``: If the ID belongs to an authority, this method may only be called by the owner. If the ID is an investor, it may be called by any authority permitted to work in that investor's country.

    Emits the ``RegisteredAddresses`` event.

    .. code-block:: python

        >>> kyc.registerAddresses(id_, [accounts[4], accounts[5]], {'from': accounts[0]})

        Transaction sent: 0xf508d5c72a1f707d88a0af4dbfc1007ecf2a7f04aa53bfcba2862e46fe3e647d
        KYCRegistrar.registerAddresses confirmed - block: 7   gas used: 60329 (0.75%)
        <Transaction object '0xf508d5c72a1f707d88a0af4dbfc1007ecf2a7f04aa53bfcba2862e46fe3e647d'>

.. method:: KYCBase.restrictAddresses(bytes32 _id, address[] _addr)

    Restricts one or more addresses associated with an ID.

    In ``KYCRegistrar``: If the ID belongs to an authority, this method may only be called by the owner. If the ID is an investor, it may be called by any authority permitted to work in that investor's country.

    When restricing addresses associated to an authority, you cannot reduce the number of addresses such that the total remaining is lower than the multi-sig threshold value for that authority.

    Emits the ``RestrictedAddresses`` event.

    .. code-block:: python

        >>> kyc.restrictAddresses(id_, [accounts[4]], {'from': accounts[0]})

        Transaction sent: 0xfeb1b2316b3c35b2e08d84b3922030b97e671eec799d0fb0eaf748f69ab0866b
        KYCRegistrar.restrictAddresses confirmed - block: 8   gas used: 60533 (0.76%)
        <Transaction object '0xfeb1b2316b3c35b2e08d84b3922030b97e671eec799d0fb0eaf748f69ab0866b'>

Getting Investor Info
=====================

There are a variey of getter methods available for issuers and custodians to query information about investors. In some cases these calls will revert if no investor data is found.

Calls that Return False
-----------------------

The following calls will not revert, instead returning ``false`` or an empty result:

.. method:: KYCBase.getID(address _addr)

    Given an address, returns the investor or authority ID associated to it. If there is no association it will return an empty bytes32.

    .. code-block:: python

        >>> kyc.getID(accounts[1])
        0x1d285a37d3afce3a200a1eeb6697e59d15e8dc0d9b5132391e3ee53c7a69f18a
        >>> kyc.getID(accounts[2])
        0x0000000000000000000000000000000000000000000000000000000000000000

.. method:: KYCBase.isRegistered(bytes32 _id)

    Returns a boolean to indicate if an ID is known to the registrar contract. No permissioning checks are applied.

    .. code-block:: python

        >>> kyc.isRegistered('0x1d285a37d3afce3a200a1eeb6697e59d15e8dc0d9b5132391e3ee53c7a69f18a')
        True
        >>> kyc.isRegistered('0x81a5c449c2409c87d702e0c4a675313347faf1c39576af357dd75efe7cad4793')
        False

.. method:: KYCBase.isPermitted(address _addr)

    Given an address, returns a boolean to indicate if this address is permitted to transfer based on the following conditions:

    * Is the registring authority restricted?
    * Is the investor ID restricted?
    * Is the address restricted?
    * Has the investor's rating expired?

    .. code-block:: python

        >>> kyc.isPermitted(accounts[1])
        True
        >>> kyc.isPermitted(accounts[2])
        False

.. method:: KYCBase.isPermittedID(bytes32 _id)

    Returns a transfer permission boolean similar to ``KYCBase.isPermitted``, without a check on a specific address.

    .. code-block:: python

        >>> kyc.isPermittedID('0x1d285a37d3afce3a200a1eeb6697e59d15e8dc0d9b5132391e3ee53c7a69f18a(')
        True
        >>> kyc.isPermittedID('0x81a5c449c2409c87d702e0c4a675313347faf1c39576af357dd75efe7cad4793')
        False

Calls that Revert
-----------------

The remaining calls will revert under some conditions:

.. method:: KYCBase.getInvestor(address _addr)

    Returns the investor ID, permission status (based on the input address), rating, and country code for an investor.

    Reverts if the address is not registered.

    .. note:: This function is designed to maximize gas efficiency when calling for information prior to performing a token transfer.

    .. code-block:: python

        >>> kyc.getInvestor(a[1]).dict()
        {
            '_country': 784,
            '_id': "0x1d285a37d3afce3a200a1eeb6697e59d15e8dc0d9b5132391e3ee53c7a69f18a",
            '_permitted': True,
            '_rating': 1
        }
        >>> kyc..getInvestor(a[0])
        File "contract.py", line 277, in call
          raise VirtualMachineError(e)
        VirtualMachineError: VM Exception while processing transaction: revert Address not registered

.. method:: KYCBase.getInvestors(address _from, address _to)

    The two investor version of ``KYCBase.getInvestor``. Also used to maximize gas efficiency.

    .. code-block:: python

        >>> kyc.getInvestors(accounts[1], accounts[2]).dict()
        {
            '_country': (784, 784),
            '_id': ("0x1d285a37d3afce3a200a1eeb6697e59d15e8dc0d9b5132391e3ee53c7a69f18a", "0x9becd445b3c5703a4f1abc15870dd10c56bb4b4a70c68dba05e116551ab11b44"),
            '_permitted': (True, False),
            '_rating': (1, 2)
        }
        >>> kyc.getInvestors(accounts[1], accounts[3])
        File "contract.py", line 277, in call
          raise VirtualMachineError(e)
        VirtualMachineError: VM Exception while processing transaction: revert Receiver not Registered

.. method:: KYCBase.getRating(bytes32 _id)

    Returns the investor rating number for a given ID.

    Reverts if the ID is not registered.

    .. code-block:: python

        >>> kyc.getRating("0x1d285a37d3afce3a200a1eeb6697e59d15e8dc0d9b5132391e3ee53c7a69f18a")
        1
        >>> kyc.getRating("0x00")
        File "contract.py", line 277, in call
          raise VirtualMachineError(e)
        VirtualMachineError: VM Exception while processing transaction: revert

.. method:: KYCBase.getRegion(bytes32 _id)

    Returns the investor region code for a given ID.

    Reverts if the ID is not registered.

    .. code-block:: python

        >>> kyc.getRegion("0x1d285a37d3afce3a200a1eeb6697e59d15e8dc0d9b5132391e3ee53c7a69f18a")
        0x653500
        >>> kyc.getRegion("0x00")
        File "contract.py", line 277, in call
          raise VirtualMachineError(e)
        VirtualMachineError: VM Exception while processing transaction: revert

.. method:: KYCBase.getCountry(bytes32 _id)

    Returns the investor country code for a given ID.

    Reverts if the ID is not registered.

    .. code-block:: python

        >>> kyc.getCountry("0x1d285a37d3afce3a200a1eeb6697e59d15e8dc0d9b5132391e3ee53c7a69f18a")
        784
        >>> kyc.getCountry("0x00")
        File "contract.py", line 277, in call
          raise VirtualMachineError(e)
        VirtualMachineError: VM Exception while processing transaction: revert

.. method:: KYCBase.getExpires(bytes32 _id)

    Returns the investor rating expiration date (in epoch time) for a given ID.

    Reverts if the ID is not registered or the rating has expired.

    .. code-block:: python

        >>> kyc.getExpires("0x1d285a37d3afce3a200a1eeb6697e59d15e8dc0d9b5132391e3ee53c7a69f18a")
        1600000000
        >>> kyc.getExpires("0x00")
        File "contract.py", line 277, in call
          raise VirtualMachineError(e)
        VirtualMachineError: VM Exception while processing transaction: revert

Events
======

Both KYC implementations include the following events.

The ``authority`` value in each event is the ID hash of the authority that called the method where the event was emitted.

.. method:: KYCBase.NewInvestor(bytes32 indexed id, uint16 indexed country, bytes3 region, uint8 rating, uint40 expires, bytes32 indexed authority)

    Emitted when a new investor is added to the registry with ``KYCBase.addInvestor``.

.. method:: KYCBase.UpdatedInvestor(bytes32 indexed id, bytes3 region, uint8 rating, uint40 expires, bytes32 indexed authority)

    Emitted when data about an existing investor is modified with ``KYCBase.updateInvestor``.

.. method:: KYCBase.InvestorRestriction(bytes32 indexed id, bool permitted, bytes32 indexed authority)

    Emitted when a restriction upon an investor is set or removed with ``KYCBase.setInvestorRestriction``.

.. method:: KYCBase.RegisteredAddresses(bytes32 indexed id, address[] addr, bytes32 indexed authority)

    Emitted by ``KYCBase.registerAddresses`` when new addresses are associated with an investor ID, or existing addresses have a restriction removed.

.. method:: KYCBase.RestrictedAddresses(bytes32 indexed id, address[] addr, bytes32 indexed authority)

    Emitted when a restriction is set upon addresses associated with an investor ID with ``KYCBase.restrictAddresses``.

KYCRegistrar
------------

The following events are specific to ``KYCRegistrar``'s authorities:

.. method:: KYCRegistrar.NewAuthority(bytes32 indexed id)

    Emitted when a new authority is added via ``KYCRegistrar.addAuthority``.

.. method:: KYCRegistrar.AuthorityRestriction(bytes32 indexed id, bool permitted)

    Emitted when an authority is restricted or permitted via ``KYCRegistrar.setAuthorityRestriction``.
