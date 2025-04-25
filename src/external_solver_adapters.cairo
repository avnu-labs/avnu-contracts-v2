pub mod layer_akira_adapter;
use starknet::ContractAddress;

#[derive(Copy, Drop, Serde)]
pub struct SwapResponse {
    pub sell_amount: u256,
    pub buy_amount: u256,
}

#[starknet::interface]
pub trait IExternalSolverAdapter<TContractState> {
    fn swap(
        self: @TContractState,
        user_address: ContractAddress,
        sell_token_address: ContractAddress,
        buy_token_address: ContractAddress,
        beneficiary: ContractAddress,
        external_solver_adapter_calldata: Array<felt252>,
    ) -> SwapResponse;
}
