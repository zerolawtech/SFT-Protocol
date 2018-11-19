.. _modules:

#######
Modules
#######

Issuers may attach modules to IssuingEntity or SecurityToken. When a module is attached, a call to ``getBindings`` checks the hook points that the module should be called at. Depending on the functionality of   the module it may attach at any of the following hook points:

-  ``checkTransfer``: called to verify permissions before a transfer is allowed
-  ``transferTokens``: called after a transfer has completed successfully
-  ``balanceChanged``: called after a balance has changed, such that there was not a corresponding change to another balance (e.g. token      minting and burning)

Modules can also directly change the balance of any address. Modules that are active at the IssuingEntity level can call this function on any security token, modules at the SecurityToken level can only call it on the token they are attached to.

When a module is no longer required it can be detached. This should always be done in order to optimize gas costs.

The wide range of functionality that modules can hook into allows for many different applications. Some examples include: crowdsales, country/time based token locks, right of first refusal enforcement, voting rights, dividend payments, tender offers, and bond redemption.
