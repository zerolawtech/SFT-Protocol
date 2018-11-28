.. _glossary:

#######################
Glossary
#######################

* **Authority**: A collection of one or more addresses permitted to call specific admin-level functionality in a multisig contract.
* **Custodian**: An entity that is approved to hold tokens on behalf of multiple investors. Common examples of custodians include broker/dealers and secondary markets.
* **Entity**: A participant in the SFT protocol. Entity may refer to natural persons or corporations.
* **Hook**: The point at which a module attaches to a method in a parent contract.
* **Issuer**: An entity that creates and sells security tokens.
* **Investor**: An entity that has passed KYC/AML checks and is able to hold and transfer security tokens.
* **Module**: A non-essential smart contract associated with an IssuingEntity or SecurityToken contract by an issuer, used to add extra transfer permissioning or handle on-chain governance events.
* **Owner**: The highest authority of a contract, set durin deployment. Only the owner is capable of creating or restricting other authorities on that contract.
* **Rating**: A number assigned to each investor that corresponds to their accreditation status.
* **Region**: Refers to the state, province, or other principal subdivision that an investor resides in.
* **Security Token**: An ERC-20 compliant token, created by an issuer, who's transferrability is restricted through on-chain logic.
* **Threshold**: The number of required calls from an authority to an admin-level function before it executes. This value cannot be greater the number of addresses associated with the authority.
* **Registrar**: A whitelist contract that associates ethereum addresses to specific investors.
