mod ekubo_adapter;
mod haiko_adapter;
mod haiko_replicating_solver_adapter;
mod jediswap_adapter;
mod myswap_adapter;
mod myswapv2_adapter;
mod nostra_adapter;
mod nostrav2_adapter;
mod sithswap_adapter;
mod starkdefi_adapter;
mod tenkswap_adapter;
mod vstrk_adapter;

use starknet::ContractAddress;

#[starknet::interface]
trait ISwapAdapter<TContractState> {
    fn swap(
        self: @TContractState,
        exchange_address: ContractAddress,
        token_from_address: ContractAddress,
        token_from_amount: u256,
        token_to_address: ContractAddress,
        token_to_min_amount: u256,
        to: ContractAddress,
        additional_swap_params: Array<felt252>,
    );
}
