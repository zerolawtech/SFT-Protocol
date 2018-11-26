.. _multisig:

#######################
MultiSig Implementation
#######################

:ref:`issuing-entity` and :ref:`custodian` contracts both implement a common multisig functionality that allows the contract owner to designate other authorities the ability to call specific admin-level contract methods.

:ref:`kyc-registrar` contracts use a slightly modified implementation.

It may be useful to also view the
`MultiSig.sol <https://github.com/SFT-Protocol/security-token/tree/master/contracts/components/MultiSig.sol>`__ source code
while reading this document.

Deployment
==========

The **owner** is declared during deployment. The owner is the highest contract authority, impossible to restrict and the only entity capable of creating or restricting other authorities on the contract.

.. method:: MultiSig.constructor(address[] _owners, uint32 _threshold)

    * ``_owners``: One or more addresses to associate with the contract owner. The address deploying the contract is not implicitly included within the owner list.
    * ``_threshold``: The number of calls required for the owner to perform a multi-sig action.

    The ID of the owner is generated as a keccak of the contract address and available from the public getter ``ownerID``.

    The owner has the highest level of control over the contract. Associated addresses may always call any admin-level functionality.

Working With Authorities
========================

**Authorities** are known, trusted entities that are permitted to add, modify, or restrict investors within the registrar. Authorities are assigned a unique ID and associated with one or more addresses.

Authorities differ from the owner in that they must be explicitly
approved to call functions within the contract. These permissions may be
modified by the owner via a call to ``MultiSig.setAuthoritySignatures``. You can
check if an authority is permitted to call a specific function with the
view function ``MultiSig.isApprovedAuthority``.

Only the owner may add, modify or restrict other authorities.

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

    Associates addresses with an authority. Can be called by any authority to add to their own addresses, or by the owner to add addresses for any authority. Can also be used to re-approve a previously restricted address that is already associated to the authority.

.. method:: MultiSig.removeAuthorityAddresses(bytes32 _id, address[] _addr)

    Restricts addresses that are associated with an authority. Can be called by any authority to restrict to their own addresses, or by the owner to restrict addresses for any authority.

    Once an address has been assigned to an authority, this association may never be removed. If an association were removed it would then be possible to assign that same address to a different investor. This could be used to circumvent various contract restricions.

.. method:: MultiSig.isApprovedAuthority(address _addr, bytes4 _sig)

    Returns true if the authority associated with the given address is permitted to call the method with the given signature.

Implementing MultiSig
=====================

Multisig functionality can be implemented within any contract method as well as in external contracts.

.. method:: MultiSig._checkMultiSig()

    Internal function, used to implement multisig within a function in the same contract.

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

    .. warning:: If an external contract includes a function with the same signature as one inside the multi-sig contract, it will be impossible to set unique permissions for each function. Developers and auditors of external contracts should always keep this in mind.


