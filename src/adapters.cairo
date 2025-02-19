pub mod ekubo_adapter;
pub mod haiko_adapter;
pub mod haiko_replicating_solver_adapter;
pub mod jediswap_adapter;
pub mod myswap_adapter;
pub mod myswapv2_adapter;
pub mod nostra_adapter;
pub mod nostrav2_adapter;
pub mod sithswap_adapter;
pub mod starkdefi_adapter;
pub mod tenkswap_adapter;
pub mod vstrk_adapter;

use starknet::ContractAddress;

#[starknet::interface]
pub trait ISwapAdapter<TContractState> {
    fn swap(
        self: @TContractState,
        exchange_address: ContractAddress,
        sell_token_address: ContractAddress,
        sell_token_amount: u256,
        buy_token_address: ContractAddress,
        buy_token_min_amount: u256,
        to: ContractAddress,
        additional_swap_params: Array<felt252>,
    );
}
