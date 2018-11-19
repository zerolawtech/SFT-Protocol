Investor Data Standards
=======================

The following generation and format standards should be followed across
the SFT protocol to ensure interoperability between network
participants.

Investor IDs
------------

Investor IDs are stored as a bytes32 keccak256 hash of the investor's
personally identifiable information.

For legal entities, the hash is generated from their `Global Legal
Entity Identifier
(LEI) <https://www.gleif.org/en/about-lei/iso-17442-the-lei-code-structure>`__:

    The International Organization for Standardization (ISO) 17442
    standard defines a set of attributes or legal entity reference data
    that are the most essential elements of identification. The Legal
    Entity Identifier (LEI) code itself is neutral, with no embedded
    intelligence or country codes that could create unnecessary
    complexity for users.

For natural persons, a hash is produced from a concatenation of the
following:

-  Full legal name in all capital letters without spaces
-  Date of Birth as DDMMYYYY
-  Unique tax ID from current jurisdiction of residence

If any of the malleable fields are changed (via a legal name change or a
change of home jurisdictions), the investor will be required to pass
KYC/AML again and a new investor ID will be generated. Once KYC is
passed, the tokens held in previous addresses must be transferred to
addresses associated to the new investor ID. It is impossible to remove
or change the ID association of an address.

Country Codes
-------------

Based on the `ISO-3166-1
numeric <https://en.wikipedia.org/wiki/ISO_3166-1_numeric>`__ standard.
Country codes are stored as a uint16 and follow the standard exactly.

*A CSV of country and region codes is available
`here <country-and-region-codes.csv>`__.*

Region Codes
------------

Based on the `ISO 3166-2 <https://en.wikipedia.org/wiki/ISO_3166-2>`__
standard.

Region codes are stored as a bytes3 and are generated in the following
way:

1. Convert each character of the ISO 3166-2 code to it's hexadecimal
   ASCII code point
2. Concatenate the hex values
3. Pad right where necessary

A quick example to generate region codes using python:

::

    iso3166 = "US-AL"[3:]
    iso3166 = [hex(ord(i)).replace('0x','') for i in iso3166]
    print("0x"+"".join(iso3166)).ljust(6, '0'))

-  Original code: US-AL
-  Resulting bytes32: 0x414c00

*A CSV of country and region codes is available
`here <country-and-region-codes.csv>`__.*
