# Investor IDs

For legal entities, the unique SFT identifier is based on the [Global Legal Entity Identifier (LEI) System](https://www.gleif.org/en/about-lei/iso-17442-the-lei-code-structure):

>The International Organization for Standardization (ISO) 17442 standard defines a set of attributes or legal entity reference data that are the most essential elements of identification. The Legal Entity Identifier (LEI) code itself is neutral, with no embedded intelligence or country codes that could create unnecessary complexity for users.

For individual investors, a keccack256 hash is produced as their unique identifier. The information concatenated to produce the hash is:

* Full name in all capital letters and without spaces
* Date of Birth
* Unique tax ID from current jurisdiction of residence

If any of the malleable fields are changed (via a legal name change or a change of home jurisdictions), the investor will be required to pass KYC/AML again and a new investor ID will be generated. Once KYC is passed, the contents of the previous wallets will be moved to wallets belongning to the new investor ID.
