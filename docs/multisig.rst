.. _multisig:

#######################
MultiSig Implementation
#######################

This section outlines the multi-signature, multi-owner functionality
used in IssuingEntity and Custodian contracts. Multisig functionality in
KYCRegistrar contracts use a similar implementation, you can read about
the differences in the :ref:`kyc-registrar` section.

It may be useful to also view the
`MultiSig.sol <https://github.com/SFT-Protocol/security-token/tree/master/contracts/components/MultiSig.sol>`__ source code
while reading this document.

Components
==========

Multisig contracts are based around the following key components:

-  **Authorities** are a collection of one or more addresses permitted
   to call specific admin-level functionality. Each authority is
   assigned a unique ID.
-  The **owner** is the highest authority, capable of creating or
   restricted other authorities.
-  Each authority has a unique **threshold** value, which is the number
   of required calls to a function before it executes. This value cannot
   be greater the number of addresses associated with the authority.

Deployment
==========

.. method:: MultiSig.constructor(address[] _owners, uint32 _threshold,address[] _owners, uint32 _threshold)

    * ``address[] _owners``: One or more addresses to associate with the contract owner. The address deploying the contract is not implicitly included within the owner list.
    * ``uint32 _threshold``: The number of calls required for the owner to perform a multi-sig action.

    The ID of the owner is generated as a keccak of the contract address and available from the public getter ``ownerID``.

    The owner has the highest level of control over the contract. Associated addresses may always call any admin-level functionality.


Designating Authorities
=======================

**Authorities** are known, trusted entities that are permitted to add, modify, or restrict investors within the registrar. Authorities are assigned a unique ID and associated with one or more addresses.

Only the owner may add, modify, or restrict other authorities.

.. method:: MultiSig.addAuthority(address[] _addr, bytes4[] _signatures, uint32 _approvedUntil, uint32 _threshold)

    Approves a new authority.

    * ``_addr``: One or more addresses to associated with the authority.
    * ``_signatures``: Function signatures that this authority is permitted to call.
    * ``_approvedUntil``: The epoch time that this authority is permitted to make calls until. To approve an authority forever, set it to the highest possible uint32 value of 4294967296 (February, 2106).
    * ``_threshold``: The number of calls required by this authority to perform a multi-sig action.

.. method:: MultiSig.setAuthorityApprovedUntil(bytes32 _id, uint32 _approvedUntil)

    Modifies the date an authority is approved to act until.

    The owner can restrict an authority by calling this function and setting ``_approvedUntil`` to 0.

.. method:: MultiSig.setAuthoritySignatures(bytes32 _id, bytes4[] _signatures, bool _allowed)

    Modifies call permissions for an authority.

.. method:: MultiSig.setAuthorityThreshold(bytes32 _id, uint32 _threshold)

    Modifies the multisig threshold requirement for an authority. Can be called by any authority to modify their own threshold, or by the owner to modify the threshold for anyone.

.. method:: MultiSig.addAuthorityAddresses(bytes32 _id, address[] _addr)

.. method:: MultiSig.removeAuthorityAddresses(bytes32 _id, address[] _addr)

.. method:: MultiSig.isApprovedAuthority(address _addr, bytes4 _sig)

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
==========================

.. method:: MultiSig._checkMultiSig()

    Internal functionn, used to implement multisig within a function in the same contract.

    All multi-sig functions return a single boolean to indicate if the threshold was met and the call succeeded. Functions that implement multi-sig include the following line of code, either at the start orafter the initial require statements:

    ::

        if (!_checkMultiSig()) return false;

    Calls that fail to meet the threshold will trigger an event ``MultiSigCall`` which includes the current call count and the threshold value. Once a caller meets the threshold the event ``MultiSigCallApproved`` will trigger, the call will execute, and the call count will be reset to zero.

    The number of calls to a function is recorded using a keccak hash of the call data. As such, it is required that each calling address format their call data in exactly the same way.

    Repeating a multi-sig call from the same address before reaching the threshold will revert.

.. method:: MultiSig.checkMultiSigExternal(bytes4 _sig, bytes32 _callHash)

    External function, used to implement multisig in an different contract.

    * ``_sig``: The original function signature being called
    * ``_callHash``: a keccak hash of the original calldata

    Use the following code to implement this in an external contract:

    ::

        bytes32 _callHash = keccak256(msg.data);
        if (!MultiSigContract.checkMultiSigExternal(msg.sig, _callHash)) {
            return false;
        }

    This function relies on ``tx.origin`` to verify that the original caller is an approved authority. Permissions are checked against the signature value in the same way as with an internal call. The recorded keccak hash of the call is formed by joining the address of the calling contract, the signature, and the supplied call hash. As such it is impossible to exploit the external call to advance the count on internal multisig events.

    An important security consideration: If an external contract includes a function with the same signature as a one inside the multi-sig contract, it will be impossible to set unique permissions for each function. Developers and auditors of external contracts should always keep this in mind.


