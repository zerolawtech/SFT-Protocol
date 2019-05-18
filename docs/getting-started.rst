.. _getting-started:

###############
Getting Started
###############

This is a quick explanation of the minimum steps required to deploy and use each contract of the protocol.

To setup a simple test environment using the brownie console:

.. code-block:: python

    $ brownie console
    Brownie v1.0.0 - Python development framework for Ethereum

    Brownie environment is ready.
    >>> run('deployment')

This runs the ``main`` function in `scripts/deployment.py <https://github.com/HyperLink-Technology/SFT-Protocol/blob/master/scripts/deployment.py>`__ which:

* Deploys ``KYCRegistrar`` from ``accounts[0]``
* Deploys ``IssuingEntity`` from ``accounts[0]``
* Deploys ``SecurityToken`` from ``accounts[0]`` with an initial authorized supply of 1,000,000 tokens
* Associates the contracts
* Approves ``accounts[1:7]`` in ``KYCRegistrar``, with investor ratings 1-2 and country codes 1-3
* Approves investors from country codes 1-3 in ``IssuingEntity``

From this configuration, the contracts are ready to mint and transfer tokens:

.. code-block:: python

    >>> token = SecurityToken[0]
    >>> token.mint(accounts[1], 1000, {'from': accounts[0]})

    Transaction sent: 0x77ec76224d90763641971cd61e99711c911828053612cc16eb2e5d7faa20815e
    SecurityToken.mint confirmed - block: 13   gas used: 229092 (2.86%)
    <Transaction object '0x77ec76224d90763641971cd61e99711c911828053612cc16eb2e5d7faa20815e'>
    >>>
    >>> token.transfer(accounts[2], 1000, {'from': accounts[1]})

    Transaction sent: 0x29d9786ca39e79714581b217c24593546672e31dbe77c64804ea2d81848f053f
    SecurityToken.transfer confirmed - block: 14   gas used: 192451 (2.41%)
    <Transaction object '0x29d9786ca39e79714581b217c24593546672e31dbe77c64804ea2d81848f053f'>

KYC Registrar
=============

There are two types of investor registry contracts:

* `KYCRegistrar.sol <https://github.com/HyperLink-Technology/SFT-Protocol/blob/master/contracts/KYCRegistrar.sol>`__ can be maintained by one or more authorities and used as a shared whitelist by many issuers
* `KYCIssuer.sol <https://github.com/HyperLink-Technology/SFT-Protocol/blob/master/contracts/KYCIssuer.sol>`__ is a more bare-bones registry, unique to a single issuer

Owner addresses are able to add investors to the registrar whitelist using ``KYCRegistrar.addInvestor``.

.. code-block:: python

    >>> kyc = accounts[0].deploy(KYCRegistrar, [accounts[0]], 1)

    Transaction sent: 0xd10264c1445aad4e9dc84e04615936624e0b96596fec2097bebc83f9d3e69664
    KYCRegistrar.constructor confirmed - block: 2   gas used: 2853810 (35.67%)
    KYCRegistrar deployed at: 0x40b49Ad1B8D6A8Df6cEdB56081D51b69e6569e06
    <KYCRegistrar Contract object '0x40b49Ad1B8D6A8Df6cEdB56081D51b69e6569e06'>
    >>>
    >>> kyc.addInvestor("0x1234", 784, "0x465500", 2, 9999999999, (accounts[3],), {'from': accounts[0]})

    Transaction sent: 0x47581e5b276298427f6a520353622b96cdecb29dff7269f03d7c957435398ebd
    KYCRegistrar.addInvestor confirmed - block: 3   gas used: 120707 (1.51%)
    <Transaction object '0x47581e5b276298427f6a520353622b96cdecb29dff7269f03d7c957435398ebd'>


See the :ref:`kyc` page for a detailed explanation of how to use registry contracts.

Issuing Tokens
==============

Issuing tokens and being able to transfer them requires the following steps:

**1.** Deploy `IssuingEntity.sol <https://github.com/HyperLink-Technology/SFT-Protocol/blob/master/contracts/IssuingEntity.sol>`__.

    .. code-block:: python

        >>> issuer = accounts[0].deploy(IssuingEntity, [accounts[0]], 1)

        Transaction sent: 0xb37d8d16b266796e64fde6a4e9813ae0673dddaeb63022d91c706612ee741972
        IssuingEntity.constructor confirmed - block: 2   gas used: 6473451 (80.92%)
        IssuingEntity deployed at: 0xa79269260195879dBA8CEFF2767B7F2B5F2a54D8
        <IssuingEntity Contract object '0xa79269260195879dBA8CEFF2767B7F2B5F2a54D8'>

**2.** Call ``IssuingEntity.setRegistrar`` to add one or more investor registries. You may maintain your own registry and/or use those belonging to trusted third parties.

    .. code-block:: python

        >>> issuer.setRegistrar(kyc, True, {'from': accounts[0]})

        Transaction sent: 0x606326c8b2b8f1541c333ef5a5cd44592efb50530c6326e260e728095b3ec2bd
        IssuingEntity.setRegistrar confirmed - block: 3   gas used: 61246 (0.77%)
        <Transaction object '0x606326c8b2b8f1541c333ef5a5cd44592efb50530c6326e260e728095b3ec2bd'>

**3.** Deploy `SecurityToken.sol <https://github.com/HyperLink-Technology/SFT-Protocol/blob/master/contracts/SecurityToken.sol>`__. Enter the address of the issuer contract from step one in the constructor. The authorized supply is set at deployment, the initial total supply will be zero.

    .. code-block:: python

        >>> token = accounts[0].deploy(SecurityToken, issuer, "Test Token", "TST", 1000000)

        Transaction sent: 0x4d2bbbc01d026de176bf5749e6e1bd22ba6eb40a225d2a71390f767b2845bacb
        SecurityToken.constructor confirmed - block: 4   gas used: 3346083 (41.83%)
        SecurityToken deployed at: 0x099c68D84815532A2C33e6382D6aD2C634E92ef6
        <SecurityToken Contract object '0x099c68D84815532A2C33e6382D6aD2C634E92ef6'>

**4.** Call ``IssuingEntity.addToken`` to attach the token to the issuer.

    .. code-block:: python

        >>> issuer.addToken(token, {'from': accounts[0]})

        Transaction sent: 0x8e93cd6b85d1e993755e9fe31eb14ce600706eaf98d606156447d8e431db5db9
        IssuingEntity.addToken confirmed - block: 5   gas used: 61630 (0.77%)
        <Transaction object '0x8e93cd6b85d1e993755e9fe31eb14ce600706eaf98d606156447d8e431db5db9'>

**5.** Call ``IssuingEntity.setCountries`` to approve investors from specific countries to hold the tokens.

    .. code-block:: python

        >>> issuer.setCountries([784],[1],[0], {'from': accounts[0]})

        Transaction sent: 0x7299b96013acb4661f4b7f05016c0de6726d2337032740aa29f5407cdabde0c3
        IssuingEntity.setCountries confirmed - block: 6   gas used: 72379 (0.90%)
        <Transaction object '0x7299b96013acb4661f4b7f05016c0de6726d2337032740aa29f5407cdabde0c3'>

**6.** Call ``SecurityToken.mint`` to create new tokens, up to the authorized supply.

    .. code-block:: python

        >>> token.mint(accounts[1], 1000, {'from': accounts[0]})

        Transaction sent: 0x77ec76224d90763641971cd61e99711c911828053612cc16eb2e5d7faa20815e
        SecurityToken.mint confirmed - block: 13   gas used: 229092 (2.86%)
        <Transaction object '0x77ec76224d90763641971cd61e99711c911828053612cc16eb2e5d7faa20815e'>


At this point, the issuer will be able to transfer tokens to any address that has been whitelisted by one of the approved investor registries *if the investor meets the country and rating requirements*.

Note that the issuer's balance is assigned to the IssuingEntity contract. The issuer can transfer these tokens with a normal call to ``SecurityToken.transfer`` from any approved address. Sending tokens to any address associated with the issuer will increase the balance on the IssuingEntity contract.

See the :ref:`issuing-entity` and :ref:`security-token` pages for detailed explanations of how to use these contracts.

Transferring Tokens
===================

`SecurityToken.sol <https://github.com/HyperLink-Technology/SFT-Protocol/blob/master/contracts/SecurityToken.sol>`__ is based on the `ERC20 Token Standard <https://theethereum.wiki/w/index.php/ERC20_Token_Standard>`__. Token transfers may be performed in the same ways as any token using this standard. However, in order to send or receive tokens you must:

* Be approved in one of the KYC registries associated to the token issuer
* Meet the approved country and rating requirements as set by the issuer
* Pass any additional checks set by the issuer

You can check if a transfer will succeed without performing a transaction by calling the ``SecurityToken.checkTransfer`` method within the token contract.

.. code-block:: python

    >>> token.checkTransfer(accounts[8], accounts[2], 500)
      File "/contract.py", line 277, in call
    raise VirtualMachineError(e)
    VirtualMachineError: VM Exception while processing transaction: revert Address not registered

    >>> token.checkTransfer(accounts[1], accounts[2], 500)
    True

Restrictions imposed on investor limits, approved countries and minimum ratings are only checked when receiving tokens. Unless an address has been explicitly blocked, it will always be able to send an existing balance. For example, an investor may purchase tokens that are only available to accredited investors, and then later their accreditation status expires. The investor may still transfer the tokens they already have, but may not receive any more tokens.

Transferring a balance between two addresses associated with the same investor ID does not have the same restrictions imposed, as there is no change of ownership. An investor with multiple addresses may call ``SecurityToken.transferFrom`` to move tokens from any of their addresses without first using the ``SecurityToken.approve`` method. The issuer can also use ``SecurityToken.transferFrom`` to move any investor's tokens, without prior approval.

See the :ref:`security-token` page for a detailed explanation of how to use this contract.

Custodians
==========

There are many types of custodians possible. Included in the core SFT contracts is `OwnedCustodian.sol <https://github.com/HyperLink-Technology/SFT-Protocol/blob/master/contracts/custodians/OwnedCustodian.sol>`__, which is a basic implementation with a real-world owner.

Once a custodian contract is deployed you must attach it to an IssuingEntity with ``IssuingEntity.addCustodian``.

.. code-block:: python

    >>> cust = accounts[0].deploy(OwnedCustodian, [accounts[0]], 1)

    Transaction sent: 0x11540767a467504e3ddd03c8c2423840a69bd82a6f28db33ea869570b87486f0
    OwnedCustodian.constructor confirmed - block: 13   gas used: 3326386 (41.58%)
    OwnedCustodian deployed at: 0x3BcC6Ad6CFbB1997eb9DA056946FC38a6b5E270D
    <OwnedCustodian Contract object '0x3BcC6Ad6CFbB1997eb9DA056946FC38a6b5E270D'>
    >>>
    >>> issuer.addCustodian(cust, {'from': accounts[0]})

    Transaction sent: 0x63d13a81c73ed614ea68f1db8cc005bd860c6f2fb0ef7d590488672bd3edc5df
    IssuingEntity.addCustodian confirmed - block: 14   gas used: 78510 (0.98%)
    <Transaction object '0x63d13a81c73ed614ea68f1db8cc005bd860c6f2fb0ef7d590488672bd3edc5df'>

At this point, transfers work in the following ways:

* Investors send tokens into the custodian contract just like they would any other address, using ``SecurityToken.transfer`` or ``SecurityToken.transferFrom``.

    .. code-block:: python

        >>> token.transfer(cust, 10000, {'from': accounts[1]})

        Transaction sent: 0x4b09b29216d130dc06798ee673759a4e77e4823655c6477e895242f027726412
        SecurityToken.transfer confirmed - block: 16   gas used: 155761 (1.95%)
        <Transaction object '0x4b09b29216d130dc06798ee673759a4e77e4823655c6477e895242f027726412'>

* Internal transfers within the custodian are done via ``OwnedCustodian.transferInternal``.

    .. code-block:: python

        >>> cust.transferInternal(token, accounts[1], accounts[2], 5000, {'from': accounts[0]})

        Transaction sent: 0x1c5cf1d01d2d5f9b9d9e801d8e2a0b9b2eb50fa11fbe03864b69ccf0fe2c03fc
        OwnedCustodian.transferInternal confirmed - block: 17   gas used: 189610 (2.37%)
        <Transaction object '0x1c5cf1d01d2d5f9b9d9e801d8e2a0b9b2eb50fa11fbe03864b69ccf0fe2c03fc'>

* Transfers out of the custodian contract are initiated with ``OwnedCustodian.transfer``.

    .. code-block:: python

        >>> cust.transfer(token, accounts[2], 5000, {'from': accounts[0]})

        Transaction sent: 0x227f7c24d68d63aa567c16458e039a283481ef5fd79d8b9e48c88b033ff18f79
        OwnedCustodian.transfer confirmed - block: 18   gas used: 149638 (1.87%)
        <Transaction object '0x227f7c24d68d63aa567c16458e039a283481ef5fd79d8b9e48c88b033ff18f79'>


You can see an investor's custodied balance using ``SecurityToken.custodianBalanceOf``.

.. code-block:: python

    >>> token.custodianBalanceOf(accounts[1], cust)
    5000

See the :ref:`custodian` page for a detailed explanation of how to use this contract.
