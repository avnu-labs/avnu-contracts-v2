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

Here is the interface of the contract:

```cairo
#[starknet::interface]
trait IExchange<TContractState> {
    fn get_owner(self: @TContractState) -> ContractAddress;
    fn transfer_ownership(ref self: TContractState, new_owner: ContractAddress) -> bool;
    fn upgrade_class(ref self: TContractState, new_class_hash: ClassHash) -> bool;
    fn get_adapter_class_hash(self: @TContractState, exchange_address: ContractAddress) -> ClassHash;
    fn set_adapter_class_hash(ref self: TContractState, exchange_address: ContractAddress, adapter_class_hash: ClassHash) -> bool;
    fn get_fees_active(self: @TContractState) -> bool;
    fn set_fees_active(ref self: TContractState, active: bool) -> bool;
    fn get_fees_recipient(self: @TContractState) -> ContractAddress;
    fn set_fees_recipient(ref self: TContractState, recipient: ContractAddress) -> bool;
    fn get_fees_bps_0(self: @TContractState) -> u128;
    fn set_fees_bps_0(ref self: TContractState, bps: u128) -> bool;
    fn get_fees_bps_1(self: @TContractState) -> u128;
    fn set_fees_bps_1(ref self: TContractState, bps: u128) -> bool;
    fn get_swap_exact_token_to_fees_bps(self: @TContractState) -> u128;
    fn set_swap_exact_token_to_fees_bps(ref self: TContractState, bps: u128) -> bool;
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
