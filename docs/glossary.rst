.. _glossary:

########
Glossary
########

* **Authority**: A collection of one or more addresses permitted to call specific admin-level functionality in a multisig contract.
* **Custodian**: An entity that holds tokens on behalf of investors, without taking beneficial ownership. May be a natural person, legal entity, or autonomous smart contract. Examples of custodians include broker/dealers, escrow agreements and secondary markets.
* **Entity**: A participant in the SFT protocol. Entity may refer to natural persons or legal entities.
* **Hook**: The point at which a module attaches to a method in a parent contract.
* **Issuer**: An entity that creates and sells security tokens.
* **Investor**: An entity that has passed KYC/AML checks and is able to hold and transfer security tokens.
* **Module**: A non-essential smart contract associated with a token or custodian contract, used to add extra transfer permissioning or handle on-chain governance events.
* **Owner**: The highest authority of a contract, set durin deployment. Only the owner is capable of creating or restricting other authorities on that contract.
* **Rating**: A number assigned to each investor that corresponds to their accreditation status.
* **Region**: Refers to the state, province, or other principal subdivision that an investor resides in.
* **Security Token**: An ERC-20 compliant token, created by an issuer, who's transferrability is restricted through on-chain logic.
* **Threshold**: The number of required calls from an authority to an admin-level function before it executes. This value cannot be greater the number of addresses associated with the authority.
* **Registrar**: A whitelist contract that associates Ethereum addresses to specific investors.
