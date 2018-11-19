.. _issuing-entity:

##############
Issuing Entity
##############

Before an issuer can create a security token they must deploy an IssuingEntity contract. This contract has several key purposes:

-  Holds a whitelist of associated KYC registries that investor data can be pulled from
-  Tracks investor counts and total balances across all security tokens deployed by the issuer
-  Enforces permissions relating to investor limits and authorized countries
-  Holds a mapping of hashes for legal documents related to the issuer
