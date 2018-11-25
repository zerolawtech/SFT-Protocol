.. _kyc-registrar:

#############
KYC Registrar
#############

KYCRegistrar contracts are registries that hold information on the identity, region, and rating of investors.

Registries may be maintained by a single entity, or a federation of entities where each are approved to provide identification services for their specific jurisdiction. The contract owner can authorize other entities to add investors within specified countries.

Contract authorities associate addresses to ID hashes that denote the identity of the investor who owns the address. More than one address may be associated to the same hash. Anyone can call ``KYCRegistrar.getID`` to see which hash is associated to an address, and then using this ID call functions to query information about the investor's region and accreditation rating.

Registry contracts implement a variation of the standard :ref:`multisig` functionality used in other contracts within the protocol. This document assumes familiarity with the standard multi-sig implementation, and will only highlight the differences.

It may be useful to also view the `KYCRegistrar.sol <https://github.com/SFT-Protocol/security-token/tree/master/contracts/KYCRegistrar.sol>`__ source code while reading this document.

Deployment
==========

The **owner** is declared during deployment. The owner is the highest contract authority, impossible to restrict and the only entity capable of creating or restricting other authorities on the contract.

.. method:: KYCRegistrar.constructor(address[] _owners, uint32 _threshold)

    * ``_owners``: One or more addresses to associate with the contract owner. The address deploying the contract is not implicitly included within the owner list.
    * ``_threshold``: The number of calls required for the owner to perform a multi-sig action. Cannot exceed the length of ``_owners``.

    The ID of the owner is generated as a keccak of the contract address and available from the public getter ``ownerID``.

Working with Authorities
========================

**Authorities** are known, trusted entities that are permitted to add, modify, or restrict investors within the registrar. Authorities are assigned a unique ID and associated with one or more addresses.

Only the owner may add, modify or restrict other authorities.

.. method:: KYCRegistrar.addAuthority(address[] _addr, uint16[] _countries, uint32 _threshold)

    Creates a new authority.

    * ``_owners``: One or more addresses to associate with the authority
    * ``_countries``: Countries that the authority is approved to act in
    * ``_threshold``: The number of calls required for the authority to perform a multi-sig action. Cannot exceed the length of ``_owners``

    Authorities do not require explicit permission to call any contract functions. However, they may only add, modify or restrict investors in countries that they have been approved to operate in.

    Once an authority has been designated they may use ``KYCRegistrar.registerAddresses`` or ``KYCRegistrar.restrictAddresses`` to modify their associated addresses.

.. method:: KYCRegistrar.setAuthorityCountries(bytes32 _id, uint16[] _countries, bool _auth)

    Modifies the country permissions for an authority. Use ``_auth`` to determine if the call is permissive or restrictive.

.. method:: KYCRegistrar.setAuthorityThreshold(bytes32 _id, uint32 _threshold)

    Modifies the multisig threshold requirement for an authority. Can be called by any authority to modify their own threshold, or by the owner to modify the threshold for anyone.

    You cannot set the threshold higher than the number of associated, unrestricted addresses for the authority.

.. method:: KYCRegistrar.setAuthorityRestriction(bytes32 _id, bool _permitted)

    Modifies the permitted state of an authority.

    If an authority has been compromised or found to be acting in bad faith, the owner may apply a broad restriction upon them with this method. This will also restrict every investor that was approved by the authority.

    A list of investors that were approved by the restricted authority can be obtained by looking at ``NewInvestor`` and ``UpdatedInvestor`` events. Once the KYC/AML of these investors has been re-verified, the restriction upon them may be removed by calling either ``KYCRegistrar.updateInvestor`` or ``KYCRegistrar.setInvestorAuthority`` to change which authority they are associated with.

Working with Investors
======================

**Investors** are natural persons or legal entities who have passed KYC/AML checks and are approved to send and receive security tokens.

Each investor is assigned a unique ID and is associated with one or more addresses. They are also assigned an expiration time for their rating. This is useful in jurisdictions where accreditation status requires periodic reconfirmation.

Authorites may add, modify, or restrict investors in any country that they have been approved to operate in by the owner.  See the :ref:`data-standards` documentation for detailed information on how this information is generated and formatted.

.. method:: KYCRegistrar.generateID(string _idString)

    Returns the keccak hash of the supplied string. Can be used by an authority to generate an investor ID hash from their KYC information.

.. method:: KYCRegistrar.addInvestor(bytes32 _id, uint16 _country, bytes3 _region, uint8 _rating, uint40 _expires, address[] _addr)

    Adds an investor to the registrar.

    * ``_id``: Investor's bytes32 ID hash
    * ``_country``: Investor country code
    * ``_region``: Investor region code
    * ``_rating``: Investor rating code
    * ``_expires``: The epoch time that the investor rating is valid until
    * ``_addr```: One or more addresses to associate with the investor

    Similar to authorities, addresses associated with investors can be modified by calls to ``KYCRegistrar.registerAddresses`` or ``KYCRegistrar.restrictAddresses``.

.. method:: KYCRegistrar.updateInvestor(bytes32 _id, bytes3 _region, uint8 _rating, uint40 _expires)

    Updates information on an existing investor.

    Due to the way that the investor ID is generated, it is not possible to modify the country that an investor is associated with. An investor who changes their legal country of residence will have to resubmit KYC, be assigned a new ID, and transfer their tokens to a different address.

.. method:: KYCRegistrar.setInvestorRestriction(bytes32 _id, bool _permitted)

    Modifies the restricted status of an investor.  An investor who is restricted will be unable to send or receive tokens.

.. method:: KYCRegistrar.setInvestorAuthority(bytes32[] _id, bytes32 _authID)

    Modifies the authority that is associated with one or more investors.

    This method is only callable by the owner. It can be used after an authority is restricted, to remove the implied restriction upon investors that were added by that authority.

Adding and Restricting Addresses
================================

Each authority and investor has one or more addresses associated to them. Once an address has been assigned to an ID, this association may never be removed. If an association were removed it would then be possible to assign that same address to a different investor. This could be used to circumvent transfer restrictions on tokens, allowing for non-compliant token ownership.

In situations of a lost or compromised private key the address may instead be flagged as restricted. In this case any tokens in the restricted address can be retrieved using another associated, unrestricted address.

.. method:: KYCRegistrar.registerAddresses(bytes32 _id, address[] _addr)

    Associates one or more addresses to an ID, or removes restrictions imposed upon already associated addresses.

    If the ID belongs to an authority, this method may only be called by the owner. If the ID is an investor, it may be called by any authority permitted to work in that investor's country.

.. method:: KYCRegistrar.restrictAddresses(bytes32 _id, address[] _addr)

    Restricts one or more addresses associated with an ID.

    If the ID belongs to an authority, this method may only be called by the owner. If the ID is an investor, it may be called by any authority permitted to work in that investor's country.

    When restricing addresses associated to an authority, you cannot reduce the number of addresses such that the total remaining is lower than the multi-sig threshold value for that authority.

Getting Investor Info
=====================

Issuers and custodians may use the following getter methods to query information about an investor:

.. method:: KYCRegistrar.getID(address _addr)

    Given an address, returns the investor or authority ID associated to it. If there is no association it will return an empty bytes32.

.. method:: KYCRegistrar.getInvestor(address _addr)

    Returns the investor ID, permission status (based on the input address), rating, and country code for an investor.

    .. note:: This function is designed to maximize gas efficiency when calling for information prior to performing a token transfer.

.. method:: KYCRegistrar.getInvestors(address _from, address _to)

    The two investor version of ``KYCRegistrar.getInvestor``. Also used to maximize gas efficiency.

.. method:: KYCRegistrar.getRating(bytes32 _id)

    Returns the investor rating number for a given ID.

.. method:: KYCRegistrar.getRegion(bytes32 _id)

    Returns the investor region code for a given ID.

.. method:: KYCRegistrar.getCountry(bytes32 _id)

    Returns the investor country code for a given ID.

.. method:: KYCRegistrar.getExpires(bytes32 _id)

    Returns the investor rating expiration date (in epoch time) for a given ID.

.. method:: KYCRegistrar.isPermitted(address _addr)

    Given an address, returns a boolean to indicate if this address is permitted to transfer based on the following conditions:

    * Is the registring authority restricted?
    * Is the investor ID restricted?
    * Is the address restricted?
    * Has the investor's rating expired?
