.. _multisig:

#######################
MultiSig Implementation
#######################

This document outlines the multi-signature, multi-owner functionality
used in IssuingEntity and Custodian contracts. Multisig functionality in
KYCRegistrar contracts use a similar implementation, you can read about
the differences in the :ref:`kyc-registrar`.

It may be useful to also view the
`MultiSig.sol <https://github.com/SFT-Protocol/security-token/tree/master/contracts/components/MultiSig.sol>`__ source code
while reading this document.

Components
----------

Multisig contracts are based around the following key components:

-  **Authorities** are a collection of one or more addresses permitted
   to call specific admin-level functionality. Each authority is
   assigned a unique ID.
-  The **owner** is the highest authority, capable of creating or
   restricted other authorities.
-  Each authority has a unique **threshold** value, which is the number
   of required calls to a function before it executes. This value cannot
   be greater the number of addresses associated with the authority.

Initial Setup
-------------

Contracts that implement multi-sig require 2 arguments in the
constructor:

-  ``address[] _owners``: One or more addresses to associate with the
   contract owner. The address deploying the contract is not implicitly
   included within the owner list.
-  ``uint32 _threshold``: The number of calls required for the owner to
   perform a multi-sig action.

The owner has the highest level of control over the contract. Associated
addresses may always call any admin-level functionality.

Designating Authorities
-----------------------

After deployment the owner may designate authorities using the
``AddAuthority`` function, which takes the following arguments:

-  ``address[] _owners``: One or more addresses to associated with the
   authority.
-  ``bytes4[] _signatures``: Function signatures that this authority is
   permitted to call.
-  ``uint32 _approvedUntil``: The epoch time that this authority is
   permitted to make calls until. To approve an authority forever, set
   it to the highest possible uint32 value of 4294967296 (February,
   2106).
-  ``uint32 _threshold``: The number of calls required by this authority
   to perform a multi-sig action.

Authorities differ from the owner in that they must be explicitly
approved to call functions within the contract. These permissions may be
modified by the owner via a call to ``setAuthoritySignatures``. You can
check if an authority is permitted to call a specific function with the
view function ``isApprovedAuthority``.

Authorities may also be given a time-based restriction, either at the
time of creation or by calling ``setAuthorityApprovedUntil``. The owner
can also restrict an authority by calling this function and setting
``_approvedUntil`` to 0.

Authorities may add or remove associated addresses with
``addAuthorityAddresses`` or ``removeAuthorityAddresses``. The owner may
call this function to add or remove addresses for any authority.

It is important to note that **once an address has been associated to an
authority, this association may never be fully removed**. Once an
address is removed, that address is now forever unavailable within the
protocol. This is necessary to prevent an address from later being
associated with a different entity, which could allow for a variety of
non-compliant actions. See the :ref:`kyc-registrar`
documentation for more information on this concept.

Calling MultiSig Functions
--------------------------

All multi-sig functions return a single boolean to indicate if the
threshold was met and the call succeeded. Functions that implement
multi-sig include the following line of code, either at the start or
after the initial require statements:

::

    if (!_checkMultiSig()) return false;

Calls that fail to meet the threshold will trigger an event
``MultiSigCall`` which includes the current call count and the threshold
value. Once a caller meets the threshold the event
``MultiSigCallApproved`` will trigger, the call will execute, and the
call count will be reset to zero.

The number of calls to a function is recorded using a keccak hash of the
call data. As such, it is required that each calling address format
their call data in exactly the same way.

Repeating a multi-sig call from the same address before reaching the
threshold will revert.

Implementing MultiSig in External Contracts
-------------------------------------------

By calling ``checkMultiSigExternal``, it is possible to implement
multi-sig functionality in external contracts with the same set of
authorities. The function arguments are:

-  ``bytes4 _sig``: The original function signature being called
-  ``bytes32 _callHash``: a keccak hash of the original calldata

To implement this in an external contract, you would use the following
code:

::

    bytes32 _callHash = keccak256(msg.data);
    if (!MultiSigContract.checkMultiSigExternal(msg.sig, _callHash)) return false;

``checkMultiSigExternal`` relies on tx.origin to verify that the
original caller is an approved authority. Permissions are checked
against the signature value in the same way as with an internal call.
The recorded keccak hash of the call is formed by joining the address of
the calling contract, the signature, and the supplied call hash. As such
it is impossible to exploit the external call to advance the count on
internal multisig events.

An important security consideration: If an external contract includes a
function with the same signature as a one inside the multi-sig contract,
it will be impossible to set unique permissions for each function.
Developers and auditors of external contracts should always keep this in
mind.
