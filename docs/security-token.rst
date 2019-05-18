.. _security-token:

#############
SecurityToken
#############

The ``SecurityToken`` contract represents a single class of fungible, non-certificated "book entry" securities.  It is based on the `ERC20 Token
Standard <https://theethereum.wiki/w/index.php/ERC20_Token_Standard>`__, with an additional ``checkTransfer`` function available to verify if transfers will succeed.

Token contracts include :ref:`multisig` and :ref:`modules` via the associated :ref:`issuing-entity` contract. See the respective documents for more detailed information.

It may be useful to view source code for the following contracts while reading this document:

* `SecurityToken.sol <https://github.com/HyperLink-Technology/SFT-Protocol/blob/master/contracts/SecurityToken.sol>`__: the deployed contract, with functionality specific to ``SecurityToken``.
* `Token.sol <https://github.com/HyperLink-Technology/SFT-Protocol/blob/master/contracts/bases/Token.sol>`__: the base contract that both ``SecurityToken`` and ``NFToken`` inherit functionality from.

Deployment
==========

.. method:: TokenBase.constructor(address _issuer, string _name, string _symbol, uint256 _authorizedSupply)

    * ``_issuer``: The address of the ``IssuingEntity`` associated with this token.
    * ``_name``: The full name of the token.
    * ``_symbol``: The ticker symbol for the token.
    * ``_authorizedSupply``: The initial authorized token supply.

    After the contract is deployed it must be associated with the issuer via ``IssuingEntity.addToken``. It is not possible to mint tokens until this is done.

    At the time of deployment the initial authorized supply is set, and the total supply is left as 0. The issuer may then mint tokens by calling ``SecurityToken.mint`` directly or via a module. See :ref:`security-token-mint-burn`.

    .. code-block:: python

        >>> token = accounts[0].deploy(SecurityToken, issuer, "Test Token", "TST", 1000000)

        Transaction sent: 0x4d2bbbc01d026de176bf5749e6e1bd22ba6eb40a225d2a71390f767b2845bacb
        SecurityToken.constructor confirmed - block: 4   gas used: 3346083 (41.83%)
        SecurityToken deployed at: 0x099c68D84815532A2C33e6382D6aD2C634E92ef6
        <SecurityToken Contract object '0x099c68D84815532A2C33e6382D6aD2C634E92ef6'>

Public Constants
================

The following public variables cannot be changed after contract deployment.

.. method:: TokenBase.name

    The full name of the security token.

    .. code-block:: python

        >>> token.name()
        Test Token

.. method:: TokenBase.symbol

    The ticker symbol for the token.

    .. code-block:: python

        >>> token.symbol()
        TST

.. method:: TokenBase.decimals

    The number of decimal places for the token. In the standard SFT implementation this is set to 0.

    .. code-block:: python

        >>> token.decimals()
        0

.. method:: TokenBase.ownerID

    The bytes32 ID hash of the issuer associated with this token.

    .. code-block:: python

        >>> token.ownerID()
        0x8be1198d7f1848ebeddb3f807146ce7d26e63d3b6715f27697428ddb52db9b63

.. method:: TokenBase.issuer

    The address of the associated IssuingEntity contract.

    .. code-block:: python

        >>> token.issuer()
        0x40b49Ad1B8D6A8Df6cEdB56081D51b69e6569e06

.. _security-token-mint-burn:

Total Supply, Minting and Burning
=================================

Authorized Supply
-----------------

Along with the ERC20 standard ``totalSupply``, token contracts include an ``authorizedSupply`` that represents the maximum allowable total supply. The issuer may mint new tokens using ``SecurityToken.mint`` until the total supply is equal to the authorized supply. The initial authorized supply is set during deployment and may be increased later using ``TokenBase.modifyAuthorizedSupply``.

A :ref:`governance` module can be deployed to dictate when the issuer is allowed to modify the authorized supply.

.. method:: TokenBase.modifyAuthorizedSupply(uint256 _value)

    Sets the authorized supply. The value may never be less than the current total supply.

    This method is callable directly by the issuer, implementing multi-sig via ``MultiSig.checkMultiSigExternal``. It may also be called by a permitted module.

    If a :ref:`governance` module has been set on the associated ``IssuingEntity``, it must provide approval whenever this method is called.

    Emits the ``AuthorizedSupplyChanged`` event.

    .. code-block:: python

        >>> token.modifyAuthorizedSupply(2000000, {'from': accounts[0]})

        Transaction sent: 0x83b7a23e1bc1248445b64f275433add538f05336a4fe07007d39edbd06e1f476
        SecurityToken.modifyAuthorizedSupply confirmed - block: 13   gas used: 46666 (0.58%)
        <Transaction object '0x83b7a23e1bc1248445b64f275433add538f05336a4fe07007d39edbd06e1f476'>

Minting and Burning
-------------------

.. method:: SecurityToken.mint(address _owner, uint256 _value)

    Mints new tokens at the given address.

    * ``_owner``: Account balance to mint tokens to.
    * ``_value``: Number of tokens to mint.

    A ``Transfer`` even will fire showing the new tokens as transferring from ``0x00`` and the total supply will increase. The new total supply cannot exceed ``authorizedSupply``.

    This method is callable directly by the issuer, implementing multi-sig via ``MultiSig.checkMultiSigExternal``. It may also be called by a permitted module.

    Modules can hook into this method via ``STModule.totalSupplyChanged``.

    .. code-block:: python

        >>> token.mint(accounts[1], 5000, {'from': accounts[0]})

        Transaction sent: 0x77ec76224d90763641971cd61e99711c911828053612cc16eb2e5d7faa20815e
        SecurityToken.mint confirmed - block: 14   gas used: 229092 (2.86%)
        <Transaction object '0x77ec76224d90763641971cd61e99711c911828053612cc16eb2e5d7faa20815e'>

.. method:: SecurityToken.burn(address _owner, uint256 _value)

    Burns tokens at the given address.

    * ``_owner``: Account balance to burn tokens from.
    * ``_value``: Number of tokens to burn.

    A ``Transfer`` event is emitted showing the new tokens as transferring to ``0x00`` and the total supply will increase.

    This method is callable directly by the issuer, implementing multi-sig via ``MultiSig.checkMultiSigExternal``. It may also be called by a permitted module.

    Modules can hook into this method via ``STModule.totalSupplyChanged``.

    .. code-block:: python

        >>> token.burn(accounts[1], 1000, {'from': accounts[0]})

        Transaction sent: 0x5414b31e3e44e657ed5ee04c0c6e4c673ab2c6300f392dfd7c282b348db0bbc7
        SecurityToken.burn confirmed - block: 15   gas used: 48312 (0.60%)
        <Transaction object '0x5414b31e3e44e657ed5ee04c0c6e4c673ab2c6300f392dfd7c282b348db0bbc7'>

Getters
-------

.. method:: TokenBase.totalSupply

    Returns the current total supply of tokens.

    .. code-block:: python

        >>> token.totalSupply()
        5000

.. method:: TokenBase.authorizedSupply

    Returns the maximum authorized total supply of tokens. Whenever the authorized supply exceeds the total supply, the issuer may mint new tokens using ``SecurityToken.mint``.

    .. code-block:: python

        >>> token.authorizedSupply()
        2000000

.. method:: TokenBase.treasurySupply

    Returns the number of tokens held by the issuer. Equivalent to calling ``TokenBase.balanceOf(issuer)``.

    .. code-block:: python

        >>> token.treasurySupply()
        1000
        >>> token.balanceOf(issuer)
        1000


.. method:: TokenBase.circulatingSupply

    Returns the total supply, less the amount held by the issuer.

    .. code-block:: python

        >>> token.circulatingSupply()
        4000

Balances and Transfers
======================

SecurityToken uses the standard ERC20 methods for token transfers, however their functionality differs slightly due to transfer permissioning requirements.

Checking Balances
-----------------

.. method:: TokenBase.balanceOf(address)

    Returns the token balance for a given address.

    .. code-block:: python

        >>> token.balanceOf(accounts[1])
        4000

.. method:: TokenBase.custodianBalanceOf(address _owner, address _cust)

    Returns the custodied token balance for a given address.

    .. code-block:: python

        >>> token.custodianBalanceOf(accounts[1], cust)
        0

.. method:: TokenBase.allowance(address _owner, address _spender)

    Returns the amount of tokens that ``_spender`` may transfer from ``_owner``'s balance using ``SecurityToken.transferFrom``.

    .. code-block:: python

        >>> token.allowance(accounts[1], accounts[2])
        1000

Checking Transfer Permissions
-----------------------------

.. method:: TokenBase.checkTransfer(address _from, address _to, uint256 _value)

    Checks if a token transfer is permitted.

    * ``_from``: Address of the sender
    * ``_to``: Address of the recipient
    * ``_value``: Amount of tokens to be transferred

    Returns ``true`` if the transfer is permitted. If the transfer is not permitted, the call will revert with the reason given in the error string.

    For a transfer to succeed it must first pass a series of checks:

    * Tokens cannot be locked.
    * Sender must have a sufficient balance.
    * Sender and receiver must be verified in a registrar associated to the issuer.
    * Sender and receiver must not be restricted by the registrar or the issuer.
    * Transfer must not result in any issuer-imposed investor limits being exceeded.
    * Transfer must be permitted by all active modules.

    Transfers between two addresses that are associated to the same ID do not undergo the same level of restrictions, as there is no change of ownership occuring.

    Modules can hook into this method via ``STModule.checkTransfer``.

    .. code-block:: python

        >>> token.checkTransfer(accounts[1], accounts[2], 100)
        True
        >>> token.checkTransfer(accounts[1], accounts[2], 10000)
        File "contract.py", line 282, in call
          raise VirtualMachineError(e)
        VirtualMachineError: VM Exception while processing transaction: revert Insufficient Balance
        >>> token.checkTransfer(accounts[1], accounts[9], 100)
        File "contract.py", line 282, in call
          raise VirtualMachineError(e)
        VirtualMachineError: VM Exception while processing transaction: revert Address not registered


.. method:: TokenBase.checkTransferCustodian(address _cust, address _from, address _to, uint256 _value)

    Checks if a custodian internal transfer of tokens is permitted. See the :ref:`custodian` documentation for more information on custodial internal transfers.

    * ``_cust``: Address of the custodian
    * ``_from``: Address of the sender
    * ``_to``: Address of the recipient
    * ``_value``: Amount of tokens to be transferred

    Returns ``true`` if the transfer is permitted. If the transfer is not permitted, the call will revert with the reason given in the error string.

    Permissioning checks for custodial transfers are identical to those of normal transfers.

    Modules can hook into this method via ``STModule.checkTransfer``. A custodial transfer can be differentiated from a regular transfer because the caller ID is be that of the custodian.

    .. code-block:: python

        >>> token.custodianBalanceOf(accounts[1], cust)
        2000
        >>> token.checkTransferCustodian(cust, accounts[1], accounts[2], 1000)
        True
        >>> token.checkTransferCustodian(cust, accounts[1], accounts[2], 5000)
        File "contract.py", line 282, in call
          raise VirtualMachineError(e)
        VirtualMachineError: VM Exception while processing transaction: revert Insufficient Custodial Balance

Transferring Tokens
-------------------

.. method:: SecurityToken.transfer(address _to, uint256 _value)

    Transfers ``_value`` tokens from ``msg.sender`` to ``_to``. If the transfer cannot be completed, the call will revert with the reason given in the error string.

    Some logic in this method deviates from the ERC20 standard, see :ref:`token-non-standard` for more information.

    All transfers will emit the ``Transfer`` event. Transfers where there is a change of ownership will also emit``IssuingEntity.TransferOwnership``.

    .. code-block:: python

        >>> token.transfer(accounts[2], 1000, {'from': accounts[1]})

        Transaction sent: 0x29d9786ca39e79714581b217c24593546672e31dbe77c64804ea2d81848f053f
        SecurityToken.transfer confirmed - block: 14   gas used: 192451 (2.41%)
        <Transaction object '0x29d9786ca39e79714581b217c24593546672e31dbe77c64804ea2d81848f053f'>

.. method:: TokenBase.approve(address _spender, uint256 _value)

    Approves ``_spender`` to transfer up to ``_value`` tokens belonging to ``msg.sender``.

    If ``_spender`` is already approved for >0 tokens, the caller must first set approval to 0 before setting a new value. This prevents the attack vector documented `here <https://docs.google.com/document/d/1YLPtQxZu1UAvO9cZ1O2RPXBbT0mooh4DYKjA_jp-RLM/edit>`__.

    No transfer permission logic is applied when making this call. Approval may be given to any address, but a transfer can only be initiated by an address that is known by one of the associated registrars. The same transfer checks also apply for both the sender and receiver, as if the transfer was done directly.

    Emits the ``Approval`` event.

    .. code-block:: python

        >>> token.approve(accounts[2], 1000, {'from': accounts[1]})

        Transaction sent: 0xa8793d57cfbf6e6ed0507c62e09c31c34feaae503b69aa6e6f4d39fad36fd7c5
        SecurityToken.approve confirmed - block: 20   gas used: 45948 (0.57%)
        <Transaction object '0xa8793d57cfbf6e6ed0507c62e09c31c34feaae503b69aa6e6f4d39fad36fd7c5'>

.. method:: SecurityToken.transferFrom(address _from, address _to, uint256 _value)

    Transfers ``_value`` tokens from ``_from`` to ``_to``.

    Prior approval must have been given via ``TokenBase.approve``, except in certain cases documented under :ref:`token-non-standard`.

    All transfers will emit the ``Transfer`` event. Transfers where there is a change of ownership will also emit``IssuingEntity.TransferOwnership``.

    Modules can hook into this method via ``STModule.transferTokens``.

    .. code-block:: python

        >>> token.transferFrom(accounts[1], accounts[3], 1000, {'from': accounts[2]})

        Transaction sent: 0x84cdd0c85d3e39f1ba4f5cbd0c4cb196c0f343c90c0819157acd14f6041fe945
        SecurityToken.transferFrom confirmed - block: 21   gas used: 234557 (2.93%)
        <Transaction object '0x84cdd0c85d3e39f1ba4f5cbd0c4cb196c0f343c90c0819157acd14f6041fe945'>

Modules
=======

Modules are attached and detached to token contracts via the associated ``IssuingEntity``. See :ref:`issuing-entity-modules-attach-detach`.

.. method:: TokenBase.isActiveModule(address _module)

    Returns ``true`` if a module is currently active on the token.  Modules that are active on the associated ``IssuingEntity`` are also considered active on tokens. If the module is not active, returns ``false``.

    .. code-block:: python

        >>> token.isActiveModule(token_module)
        True
        >>> token.isActiveModule(other_module)
        False

.. method:: TokenBase.isPermittedModule(address _module, bytes4 _sig)

    Returns ``true`` if a module is permitted to access a specific method. If the module is not active or not permitted to call the method, returns ``false``.

    .. code-block:: python

        >>> token.isPermittedModule(token_module, "0x40c10f19")
        True
        >>> token.isPermittedModule(token_module, "0xc39f42ed")
        False

Events
======

The ``SecurityToken`` contract includes the following events.

.. method:: TokenBase.Transfer(address indexed from, address indexed to, uint256 tokens)

    Emitted when a token transfer is completed via ``SecurityToken.transfer`` or ``SecurityToken.transferFrom``.

    Also emitted by ``SecurityToken.mint`` and ``SecurityToken.burn``. For minting the address of the sender will be ``0x00``, for burning it will be the address of the receiver.

.. method:: TokenBase.Approval(address indexed tokenOwner, address indexed spender, uint256 tokens)

    Emitted when an approved transfer amount is set via ``SecurityToken.approve``.

.. method:: TokenBase.AuthorizedSupplyChanged(uint256 oldAuthorized, uint256 newAuthorized)

    Emitted when the authorized supply is changed via ``TokenBase.modifyAuthorizedSupply``.
