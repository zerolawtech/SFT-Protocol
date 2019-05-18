.. _multisig:

#######################
MultiSig Implementation
#######################

:ref:`issuing-entity` and :ref:`custodian` contracts both implement a common multisig functionality that allows the contract owner to designate other authorities the ability to call specific admin-level contract methods.

``KYCRegistrar`` contracts use a slightly modified implementation. See the :ref:`kyc-registrar` documentation for more information.

It may be useful to also view the
`MultiSig.sol <https://github.com/HyperLink-Technology/SFT-Protocol/blob/master/contracts/bases/MultiSig.sol>`__ source code
while reading this document.

.. note::

    In the code examples ``MultiSig`` is deployed as a standalone contract for simplicity. In a production environment it should be included as an inherited contract, not deployed directly.

Deployment
==========

The owner is declared during deployment. The owner is the highest contract authority, impossible to restrict and the only entity capable of creating or restricting other authorities on the contract.

.. method:: MultiSig.constructor(address[] _owners, uint32 _threshold)

    * ``_owners``: One or more addresses to associate with the contract owner. The address deploying the contract is not implicitly included within the owner list.
    * ``_threshold``: The number of calls required for the owner to perform a multi-sig action.

    The owner has the highest level of control over the contract. Associated addresses may always call any admin-level functionality.

    .. code-block:: python

        >>> ms = accounts[0].deploy(MultiSig, [accounts[0], accounts[1]], 1)
        Transaction sent: 0xba276d522a5d7f99670df3640053deabb0f97b4e545be0922aeedb48b4af98cf
        MultiSig.constructor confirmed - block: 1   gas used: 1875646 (23.45%)
        MultiSig deployed at: 0xa79269260195879dBA8CEFF2767B7F2B5F2a54D8
        <MultiSig Contract object '0xa79269260195879dBA8CEFF2767B7F2B5F2a54D8'>

Public Constants
================

The following public variables cannot be changed after contract deployment.

.. method:: MultiSig.ownerID()

    The bytes32 ID hash of the issuer.

    .. code-block:: python

        >>> ms.ownerID()
        0xce1e12589ad8fb3eed11af5b9ef8788c25b574d4073d23c871e003021400c429

Working With Authorities
========================

**Authorities** are entities that are permitted to call admin-level methods within a contract. They are assigned a unique ID that is associated with one or more addresses.

Authorities differ from the owner in that they must be explicitly
approved to call functions within the contract. These permissions may be
modified by the owner via a call to ``MultiSig.setAuthoritySignatures``. You can
check if an authority is permitted to call a specific function with the
view function ``MultiSig.isApprovedAuthority``.

Only the owner may add, modify or restrict other authorities.

Setters
-------

.. method:: MultiSig.addAuthority(address[] _addr, bytes4[] _signatures, uint32 _approvedUntil, uint32 _threshold)

    Approves a new authority.

    * ``_addr``: One or more addresses to associated with the authority.
    * ``_signatures``: Function signatures that this authority is permitted to call.
    * ``_approvedUntil``: The epoch time that this authority is permitted to make calls until. To approve an authority forever, set it to the highest possible uint32 value of 4294967296 (February, 2106).
    * ``_threshold``: The number of calls required by this authority to perform a multi-sig action.

    The ID of the authority is generated from a keccak of the initial addresses associated with the authority.

    Emits the ``NewAuthority``, ``NewAuthorityAddresses`` and ``NewAuthorityPermissions`` events.

    .. code-block:: python

        >>> ms.addAuthority([accounts[2], accounts[3]], ["0xfb6e54f9", "0xd0370e78"], 2000000000, 1, {'from': accounts[0]})

        Transaction sent: 0xc3a7aa469048e288030aa8eaf90f8e12b369695ad4f487ac43efe05add1a042b
        MultiSig.addAuthority confirmed - block: 2   gas used: 160697 (2.01%)
        <Transaction object '0xc3a7aa469048e288030aa8eaf90f8e12b369695ad4f487ac43efe05add1a042b'>
        >>>
        >>> id_ = ms.getID(accounts[2])
        0x857bfe5ad6c226322d3b517d158f60ac64e53b7b500d1ac2f27117cdf911a9c6

.. method:: MultiSig.setAuthorityApprovedUntil(bytes32 _id, uint32 _approvedUntil)

    Modifies the date an authority is approved to act until.

    The owner can restrict an authority by calling this function and setting ``_approvedUntil`` to 0.

    Emits the ``ApprovedUntilSet`` event.

    .. code-block:: python

        >>> ms.setAuthorityApprovedUntil(id_, 3000000000, {'from': accounts[0]})

        Transaction sent: 0x321652c5d0cdb2d8dd6b6e6123bc8e48bdf5a745378dabf2bb3ff5944f5a9ba9
        MultiSig.setAuthorityApprovedUntil confirmed - block: 3   gas used: 42055 (0.53%)
        <Transaction object '0x321652c5d0cdb2d8dd6b6e6123bc8e48bdf5a745378dabf2bb3ff5944f5a9ba9'>

.. method:: MultiSig.setAuthoritySignatures(bytes32 _id, bytes4[] _signatures, bool _allowed)

    Modifies call permissions for an authority.

    .. warning:: If an external contract method using ``checkMultiSigExternal`` has the same signature as one inside the multi-sig contract, it will be impossible to set unique permissions for each function. Developers and auditors of external contracts should always keep this in mind.

    If permission is granted, emits the ``NewAuthorityPermissions`` event. If permission is revoked, emits the ``RemovedAuthorityPermissions`` event.

    .. code-block:: python

        >>> ms.setAuthoritySignatures(id_, ["0xfb6e54f9"], False, {'from': accounts[0]})

        Transaction sent: 0x5381f0d788c5fcf9db82a9c36696648d2cd0bfbf77dcfed99169102f37999622
        MultiSig.setAuthoritySignatures confirmed - block: 4   gas used: 28392 (0.35%)
        <Transaction object '0x5381f0d788c5fcf9db82a9c36696648d2cd0bfbf77dcfed99169102f37999622'>

.. method:: MultiSig.setAuthorityThreshold(bytes32 _id, uint32 _threshold)

    Modifies the multisig threshold requirement for an authority. The owner may call to modify the threshold for any authority. An authority that has been permitted to call this function may call to modify their own threshold.

    Emits the ``ThresholdSet`` event.

    .. code-block:: python

        >>> ms.setAuthorityThreshold(id_, 1, {'from': accounts[0]})

        Transaction sent: 0x37856411734aa9e354a265a73f143a66efadf4c7a3c94078817b430c0108d261
        MultiSig.setAuthorityThreshold confirmed - block: 9   gas used: 41376 (29.27%)
        <Transaction object '0x37856411734aa9e354a265a73f143a66efadf4c7a3c94078817b430c0108d261'>
        >>> ms.setAuthorityThreshold.call(id_, 3, {'from': accounts[0]})
        File "contract.py", line 282, in call
          raise VirtualMachineError(e)
        VirtualMachineError: VM Exception while processing transaction: revert dev: threshold too high

.. method:: MultiSig.addAuthorityAddresses(bytes32 _id, address[] _addr)

    Associates addresses with an authority. Can be called by any authority to add to their own addresses, or by the owner to add addresses for any authority. Can also be used to re-approve a previously restricted address that is already associated to the authority.

    Emits the ``NewAuthorityAddresses`` event.

    .. code-block:: python

        >>> ms.addAuthorityAddresses(id_, [accounts[4]], {'from': accounts[0]})

        Transaction sent: 0xe7654ccaaa1f9c70c958bffae9c3ce8c58289b446a83d1e746ddac090ef830c6
        MultiSig.addAuthorityAddresses confirmed - block: 10   gas used: 66482 (39.93%)
        <Transaction object '0xe7654ccaaa1f9c70c958bffae9c3ce8c58289b446a83d1e746ddac090ef830c6'>

.. method:: MultiSig.removeAuthorityAddresses(bytes32 _id, address[] _addr)

    Restricts addresses that are associated with an authority. Can be called by any authority to restrict to their own addresses, or by the owner to restrict addresses for any authority.

    Once an address has been assigned to an authority, this association may never be removed. If an association were removed it would then be possible to assign that same address to a different investor. This could be used to circumvent various contract restricions.

    Emits the ``RemovedAuthorityAddresses`` event.

    .. code-block:: python

        >>> ms.removeAuthorityAddresses(id_, [accounts[4]], {'from': accounts[0]})

        Transaction sent: 0x020d9f20ddafe91490276527ac1d4c55965ec6137dd8513025838029ab1af39b
        MultiSig.removeAuthorityAddresses confirmed - block: 11   gas used: 65962 (39.75%)
        <Transaction object '0x020d9f20ddafe91490276527ac1d4c55965ec6137dd8513025838029ab1af39b'>

Getters
-------

There are several getter methods available for to query information about multisig authorities. In some cases these calls will revert if no data is found.

Calls that Return False
***********************

.. method:: MultiSig.isAuthority(address _addr)

    Checks if an address is associated with an authority.

    .. code-block:: python

        >>> ms.isAuthority(accounts[3])
        True
        >>> ms.isAuthority(accounts[5])
        False


.. method:: MultiSig.isAuthorityID(bytes32 _id)

    Checks if an ID hash is one belonging to an authority.

    .. code-block:: python

        >>> ms.isAuthorityID(id_)
        True
        >>> ms.isAuthorityID("0x1234")
        False

.. method:: MultiSig.getID(address _addr)

    Returns the authority ID associted with a given address.  If the address is not associated with an authority, returns ``0x00``.

    .. code-block:: python

        >>> id_ = ms.getID(accounts[2])
        0x857bfe5ad6c226322d3b517d158f60ac64e53b7b500d1ac2f27117cdf911a9c6
        >>> ms.getID(accounts[6])
        0x0000000000000000000000000000000000000000000000000000000000000000

.. method:: MultiSig.isApprovedAuthority(address _addr, bytes4 _sig)

    Returns true if the given address is associated with an authority, and currently permitted to call the method with the given signature.

    This call is only a general check to see if the authority may call to the method. Specific logic within any given method may still prevent this authority from completing the call.

    .. code-block:: python

        >>> ms.isApprovedAuthority(accounts[3], "0xd0370e78")
        True
        >>> ms.isApprovedAuthority(accounts[5], "0xd0370e78")
        False
        >>> ms.isApprovedAuthority(accounts[3], "0x932324e5")
        False

Calls that Revert
*****************

The remaining calls will revert under some conditions:

.. method:: MultiSig.getAuthority(bytes32 _id)

    Given an authority ID, returns the number of approved addresses, epoch time the authority is approved until, and multisig threshold value.

    If the ID is not associated with an authority the call will revert.

    .. code-block:: python

        >>> ms.getAuthority(id_).dict()
        {
            '_addressCount': 2,
            '_approvedUntil': 3000000000,
            '_threshold': 1
        }
        >>> ms.getAuthority('0x1234')
        File "contract.py", line 282, in call
          raise VirtualMachineError(e)
        VirtualMachineError: VM Exception while processing transaction: revert

Implementing in other Contracts
===============================

Multisig functionality can be implemented within any contract method as well as in external contracts.

.. method:: MultiSig._checkMultiSig()

    Internal function, used to implement multisig within a function in the same contract.

    All multi-sig functions return a single boolean to indicate if the threshold was met and the call succeeded. Functions that implement multi-sig include the following line of code, either at the start orafter the initial require statements:

    ::

        if (!_checkMultiSig()) return false;

    Calls that fail to meet the threshold will trigger an event ``MultiSigCall`` which includes the current call count and the threshold value. Once a caller meets the threshold the event ``MultiSigCallApproved`` will trigger, the call will execute, and the call count will be reset to zero.

    The number of calls to a function is recorded using a keccak hash of the call data. As such, it is required that each calling address format their call data in exactly the same way.

    Repeating a multi-sig call from the same address before reaching the threshold will revert.

.. method:: MultiSig.checkMultiSigExternal(address _caller, bytes32 _callHash, bytes4 _sig)

    External function, used to implement multisig in an external contract.

    * ``_caller``: caller address
    * ``_callHash``: a keccak hash of the original calldata
    * ``_sig``: The original function signature being called

    Use the following code to implement this in an external contract:

    ::

        bytes32 _callHash = keccak256(msg.data);
        if (!MultiSigContract.checkMultiSigExternal(msg.sender, _callHash, msg.sig)) {
            return false;
        }

Events
======

``MultiSig`` includes the following events.

.. method:: MultiSig.MultiSigCall(bytes32 indexed id,bytes4 indexed callSignature,bytes32 indexed callHash,address caller,uint256 callCount,uint256 threshold)

    Emitted whenever a multisig call is made, but the threshold has not been reached.

.. method:: MultiSig.MultiSigCallApproved(bytes32 indexed id,bytes4 indexed callSignature,bytes32 indexed callHash,address caller)

    Emitted when a multisig call is made, and the required threshold to complete the call is reached.

.. method:: MultiSig.NewAuthority(bytes32 indexed id,uint32 approvedUntil,uint32 threshold)

    Emitted when a new multisig authority is added via ``MultiSig.addAuthority``.

.. method:: MultiSig.NewAuthorityAddresses(bytes32 indexed id,address[] added,uint32 ownerCount)

    Emitted when new addresses are associted to an authority, either via ``MultiSig.addAuthority`` or ``MultiSig.addAuthorityAddresses``.

.. method:: MultiSig.RemovedAuthorityAddresses(bytes32 indexed id,address[] removed,uint32 ownerCount)

    Emitted when authority addresses are removed via ``MultiSig.removeAuthorityAddresses``.

.. method:: MultiSig.ApprovedUntilSet(bytes32 indexed id, uint32 approvedUntil)

    Emitted when an authority's approval time is modified via ``MultiSig.setAuthorityApprovedUntil``.

.. method:: MultiSig.ThresholdSet(bytes32 indexed id, uint32 threshold)

    Emitted when an authority's threshold is modified via ``MultiSig.setAuthorityThreshold``.

.. method:: MultiSig.NewAuthorityPermissions(bytes32 indexed id, bytes4[] signatures)

    Emitted when an authority is given new method permissions, either via ``MultiSig.addAuthority`` or ``MultiSig.setAuthoritySignatures``.

.. method:: MultiSig.RemovedAuthorityPermissions(bytes32 indexed id, bytes4[] signatures)

    Emitted when an authority has a method permission removed via ``MultiSig.setAuthoritySignatures``.
