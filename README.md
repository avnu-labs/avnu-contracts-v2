# AVNU Contracts

This repository contains the contracts used by [AVNU](https://www.avnu.fi/).

If you want to learn more about AVNU, and how we are able to provide the best execution on Starknet, you can visit
our [documentation](https://doc.avnu.fi/).

## Structure

- **Exchange**: Handles the swap. It contains all the routing logic

AVNUExchange uses **Adapter**s to call each AMM.
These adapters are declared on Starknet and then called using library calls.
A mapping of "AMM Router address" to "Adapter class hash" is stored inside the AVNUExchange contract.

| Mainnet                                                            | Sepolia                                                            |
|--------------------------------------------------------------------|--------------------------------------------------------------------|
| 0x04270219d365d6b017231b52e92b3fb5d7c8378b05e9abc97724537a80e93b0f | 0x02c56e8b00dbe2a71e57472685378fc8988bba947e9a99b26a00fade2b4fe7c2 |

## Exchange contract

The Exchange contract allows to swap ERC20 tokens.

This contract implements the following components:
- [FeeComponent](src/components/fee.cairo): Manages a fees.
- [OwnableComponent](https://github.com/avnu-labs/avnu-contracts-lib/blob/main/src/components/ownable.cairo): Manages the owner of the contract. The owner of the contract is a multisig account.
- [UpgradableComponent](https://github.com/avnu-labs/avnu-contracts-lib/blob/main/src/components/upgradable.cairo): Allows the contract to be upgraded. Only the owner can upgrade the contract.

Here is the interface of the contract:

```cairo

#[starknet::interface]
pub trait IOwnable<TContractState> {

    // Ownable entry points
    fn get_owner(self: @TContractState) -> ContractAddress;
    fn transfer_ownership(ref self: TContractState, new_owner: ContractAddress);
}

#[starknet::interface]
pub trait IUpgradable<TContractState> {

    // Upgradeable entry point
    fn upgrade_class(ref self: TContractState, new_class_hash: ClassHash);
}

#[starknet::interface]
pub trait IFee<TContractState> {

    // Fees entrypoints
    fn get_fees_recipient(self: @TContractState) -> ContractAddress;
    fn set_fees_recipient(ref self: TContractState, fees_recipient: ContractAddress) -> bool;
    fn get_fees_bps_0(self: @TContractState) -> u128;
    fn set_fees_bps_0(ref self: TContractState, bps: u128) -> bool;
    fn get_fees_bps_1(self: @TContractState) -> u128;
    fn set_fees_bps_1(ref self: TContractState, bps: u128) -> bool;
    fn get_swap_exact_token_to_fees_bps(self: @TContractState) -> u128;
    fn set_swap_exact_token_to_fees_bps(ref self: TContractState, bps: u128) -> bool;
    fn get_token_fee_config(self: @TContractState, token: ContractAddress) -> TokenFeeConfig;
    fn set_token_fee_config(ref self: TContractState, token: ContractAddress, config: TokenFeeConfig) -> bool;
    fn is_integrator_whitelisted(self: @TContractState, integrator: ContractAddress) -> bool;
    fn set_whitelisted_integrator(ref self: TContractState, integrator: ContractAddress, whitelisted: bool) -> bool;
}

#[starknet::interface]
trait IExchange<TContractState> {
    
    // Exchange entrypoints
    fn get_adapter_class_hash(self: @TContractState, exchange_address: ContractAddress) -> ClassHash;
    fn set_adapter_class_hash(ref self: TContractState, exchange_address: ContractAddress, adapter_class_hash: ClassHash) -> bool;
    fn multi_route_swap(
        ref self: TContractState,
        token_from_address: ContractAddress,
        token_from_amount: u256,
        token_to_address: ContractAddress,
        token_to_amount: u256,
        token_to_min_amount: u256,
        beneficiary: ContractAddress,
        integrator_fee_amount_bps: u128,
        integrator_fee_recipient: ContractAddress,
        routes: Array<Route>,
    ) -> bool;
    fn swap_exact_token_to(
        ref self: TContractState,
        token_from_address: ContractAddress,
        token_from_amount: u256,
        token_from_max_amount: u256,
        token_to_address: ContractAddress,
        token_to_amount: u256,
        beneficiary: ContractAddress,
        routes: Array<Route>,
    ) -> bool;
}
```
The Exchange contract exposes the external/view functions of IOwnable, IUpgradeable and IFee publicly.

### Fee component

This component provides a flexible framework for managing fees in token swaps. 

The component includes the following definitions:
- `fees_recipient`: The address designated to receive the collected fees.
- `fees_bps_0`: The fee rate in basis points (bps) for routes with length = 1
- `fees_bps_1`: The fee rate in basis points (bps) for routes with length > 1
- `token_fees`: Configuration for a specific token address. It specifies:
  - The weight (used to determine whether fees are taken on the buy or sell side).
- `whitelisted_integrators`: A list of integrators exempted from certain fees.
- `swap_exact_token_to_fees_bps`: The fee rate in bps for the swap_exact_token_to entrypoint.

#### Fee Calculation Process

1. Retrieve Token Fee Configuration

First, the fee configurations for both the sell token and the buy token are retrieved to determine their respective weights. 
This helps decide whether to apply fees on the sell token or the buy token.

2. Fee is calculated based on the route complexity (len)

3. Check for Whitelisted Integrators

If the integrator is whitelisted and its fees exceed the calculated fee, no fee is applied.

## Getting Started

This repository is using [Scarb](https://docs.swmansion.com/scarb/) to install, test, build contracts

```shell
# Format
scarb fmt

# Run the tests
scarb test

# Build contracts
scarb build
```
