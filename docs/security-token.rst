.. _security-token:

##############
Security Token
##############

   SecurityToken represents a single, fungible class of securities from an issuer. It conforms to the ERC20 standard, with an additional ``checkTransfer`` function available to verify if a transfer will succeed. Before tokens can be transferred, all of the following checks must pass:

   -  Sender and receiver addresses must be validated by a KYC registrar
   -  Issuer imposed limits on investor counts: global, country specific, and accreditation rating specific
   -  Optional permissions added via modules applied at the SecurityToken and IssuingEntity level

   Transfers that move tokens between different addresses owned by the same entity (as identified in the KYC registrar) are not as heavily restricted because there is no change of ownership. Any address belonging to a single entity can call ``transferFrom`` and move tokens from any of their wallets. The issuer can use the same function to move any tokens between any address.

Components
==========

Deployment
==========

Functionality
=============

Integration
===========

Security Considerations
=======================