KYCRegistrar
============

KYCRegistrar contracts ("registrars") are whitelisting contracts that
hold information on the identity, region, and rating of investors.

Registry contracts implement a variation of the standard
`MultiSig <multisig.sol>`__ functionality used in other contracts within
the protocol. This document assumes familiarity with the standard
multi-sig implementation, and will only highlight the differences.

It may be useful to also view the
`KYCRegistrar.sol <../contracts/components/KYCRegistrar.sol>`__ source
code while reading this document.

Components
----------

Registrars are based on the following key components:

-  **Investors** are natural persons or legal entities who have passed
   KYC/AML checks and are approved to send and receive security tokens.
   Each investor is assigned a unique ID and is associated with one or
   more addresses.
-  **Authorities** are known, trusted entities that are permitted to
   add, modify, or restrict investors within the registrar. Authorities
   are also assigned a unique ID and associated with one or more
   addresses.
-  The **owner** is the initial authority declared during the deployment
   the contract. Only the owner may add, modify, or restrict other
   authorities.
-  **Issuers** are entities that have created security tokens, who rely
   on registrars for information about their token holders.

Authorities
-----------

The initial owner addresses and threshold are set during deployment. The
owner ID is generated as a keccak of the contract address.

The owner may designate authorities using the ``addAuthority`` function.
Authorities do not require explicit permission to call any contract
functions. However, they may only add, modify or restrict investors in
countries that they have been approved to operate in. This permission is
initially declared when creating the authority and may be modified later
with ``setAuthorityCountries``.

Once an authority has been designated they may use ``registerAddresses``
or ``restrictAddresses`` to modify their associated addresses.

Investors
---------

After verifying an investor's KYC/AML, an authority may call
``addInvestor`` to add the investor to the registrar.

Each investor is identified in the registrar via a unique ID hash. Their
country, region, and investor rating are also recorded on-chain. See the
`Data Standards <data-standards.md>`__ documentation for detailed
information on how this information is generated and formatted.

Investors are also assigned an expiration time for their rating. This is
useful in jurisdictions where accreditation status requires periodic
reconfirmation. An authority may update the record for an existing
investor by calling ``updateInvestor``.

Similar to authorities, addresses associated with investors are assigned
and restricted via calls to ``registerAddresses`` or
``restrictAddresses``.

Issuer Integration
------------------

Issuers must associate their
`IssuingEntity <../contracts/IssuingEntity.sol>`__ contract with one or
more registrars in order to alow investors to hold their tokens. This is
accomplished by calling ``IssuingEntity.setRegistrar``.

The investor ID associated with an address may be obtained by calling
the ``getID`` view function. The ID may then be used to call a variety
of view functions to obtain the investor's rating, region, country or
KYC expiration date.

IssuingEntity contracts primarily rely on ``getInvestor`` and
``getInvestors`` to retrieve investor information in the most gas
efficient manner possible.

See the `Third Party Integration <third-party-integration.md>`__ page
for detailed information on how to integrate contracts within the
protocol.

Security Considerations
-----------------------

Here we outline several unfavorable situations that may occur, and
guidelines for how to handle them.

Investor Changes Country
~~~~~~~~~~~~~~~~~~~~~~~~

An investor who changes their legal country of residence will
necessarily alter their ID hash. In this case the investor should
resubmit their KYC/AML to an authority within the new country, receive a
new ID hash attached to a new address, and transfer their tokens from
their old address to the new one. Their old ID may then be restricted.

Lost Invesor Private Key
~~~~~~~~~~~~~~~~~~~~~~~~

An investor who has lost a private key should contact the registry
authority and verify their identity off-chain. The authority can then
restrict the address of the lost key and add one or more new addresses
that the investor controls. The investor may retrieve tokens from the
lost address either with assistance from the issuer or by using the
``SecurityToken.transferFrom`` function. See the
`SecurityToken <security-token.md>`__ documentation for more information
on this process.

Compromised Authority
~~~~~~~~~~~~~~~~~~~~~

If an authority has been compromised or found to be acting in bad faith,
the owner may apply a broad restriction upon them using
``setAuthorityRestriction``. This will also restrict every investor that
was approved by this authority.

A list of investors that were approved by the restricted authority can
be obtained from ``NewInvestor`` and ``UpdatedInvestor`` events. Once
the KYC/AML of these investors has been re-verified, the restriction
upon them may be removed by calling either ``updateInvestor`` or
``setInvestorAuthority``.

Compromised Owner
~~~~~~~~~~~~~~~~~

If the owner is compromised or found to be acting in bad faith, issuers
can remove the registrar by calling ``IssuingEntity.setRegistrar``. This
will also restrict every investor that was approved by this registry.
These investors will have to KYC via a different authority in order to
be able to transfer their tokens.
