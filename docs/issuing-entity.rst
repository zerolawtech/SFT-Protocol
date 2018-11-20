.. _issuing-entity:

##############
Issuing Entity
##############

IssuingEntity contracts hold shared compliance logic for all security tokens created by a single issuer.

Each issuer contract includes standard :ref:`multisig` and :ref:`modules` functionality. See the respective documents for detailed information on these components.

It may be useful to also view the `IsssuingEntity.sol<https://github.com/SFT-Protocol/security-token/tree/master/contracts/IssuingEntity.sol>`__ source code while reading this document.

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

Deploying an IssuingEntity contract requires 2 arguments in the constructor:

-  ``address[] _owners``: One or more addresses to associate with the
   contract owner. The address deploying the contract is not implicitly
   included within the owner list.
-  ``uint32 _threshold``: The number of calls required for the owner to
   perform a multi-sig action.

The ID of the owner is generated as a keccak of the contract address and available from the public getter ``ownerID``.

Functionality
=============

Integration
===========

Security Considerations
=======================

