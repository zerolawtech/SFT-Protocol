# Third Party Integration
## KYC Registrar
To setup an investor registry, deploy [KYCRegistrar.sol](https://github.com/iamdefinitelyahuman/security-token/blob/master/contracts/KYCRegistrar.sol).  Owner addresses will then be able to add investors using `addInvestor` or approve other whitelisting authorities with `addAuthority`. See the [KYCRegistrar](https://github.com/iamdefinitelyahuman/security-token/blob/master/docs/KYCRegistrar.md) page for a detailed explanation of how to use the contract.

## Issuing Tokens
Issuing tokens and being able to transfer them requires the following steps:

1. Deploy [IssuingEntity.sol](https://github.com/iamdefinitelyahuman/security-token/blob/master/contracts/IssuingEntity.sol).
2. Call `IssuingEntity.addRegistrar` to add one or more investor registries. You may maintain your own registry and/or use those belonging to trusted third parties.
3. Deploy [SecurityToken.sol](https://github.com/iamdefinitelyahuman/security-token/blob/master/contracts/SecurityToken.sol). Enter the address of the issuer contract from step 1 in the constructor. The total supply of tokens will be initially creditted to the issuer.
4. Call `IssuingEntity.addToken` to attach the token to the issuer.
5. Call `IssuingEntity.setCountries` to approve investors from specific countries to hold the tokens.

At this point, you will be able to transfer tokens from the issuer to any address that has been whitelisted by one of the approved investor registries *if the investor meets the country and rating requirements*.

Note that the issuer's balance is assigned to the IssuingEntity contract. The issuer can transfer these tokens with a normal call to `SecurityToken.transfer` from any approved address. Sending tokens to any address associated with the issuer will increase the balance on the IssuingEntity contract.

You can also introduce further limitations on investor counts or attach optional modules to add more bespoke functionality. See the [IssuingEntity](https://github.com/iamdefinitelyahuman/security-token/blob/master/docs/lssuingEntity.md) and [SecurityToken](https://github.com/iamdefinitelyahuman/security-token/blob/master/docs/SecurityToken.md) pages for detailed explanations of how to use these contracts.

## Transferring Tokens
SecurityToken.sol is based on the [ERC20 Token Standard](https://theethereum.wiki/w/index.php/ERC20_Token_Standard). Token transfers may be performed in the same ways as any token using this standard.  However, in order to send or receive tokens you must also:

* Be approved in one of the KYC registries associated to the token issuer
* Meet the approved country and rating requirements as set by the issuer
* Pass any additional checks set by the issuer

You can check if a transfer will succeed without performing a transaction by calling the `checkTransfer` function of the token contract.

Restrictions imposed on investor limits, approved countries and minimum ratings do not apply if you are trying to transfer an existing balance - in these cases you will be able to send tokens but not receive any more.

Transferring a balance between two addresses associated with the same investor ID does not have the same restrictions imposed, as there is no change of ownership.  An investor with multiple addresses may call `transferFrom` to move tokens from any of their addresses without first using the `approve` method. The issuer can also use `transferFrom` to move any investor's tokens, without prior approval.
