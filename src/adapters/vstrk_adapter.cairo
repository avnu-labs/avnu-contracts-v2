use starknet::ContractAddress;

#[starknet::interface]
trait IVstrk<TContractState> {
    fn unlock(self: @TContractState, amount: u256);
}
#[starknet::interface]
trait IStrk<TContractState> {
    fn lock_and_delegate(self: @TContractState, delegatee: ContractAddress, amount: u256);
}

#[starknet::contract]
mod VstrkAdapter {
    use avnu::adapters::ISwapAdapter;
    use starknet::{contract_address_const, ContractAddress};
    use super::{IVstrkDispatcher, IVstrkDispatcherTrait, IStrkDispatcher, IStrkDispatcherTrait};

    #[storage]
    struct Storage {}

    #[abi(embed_v0)]
    impl VstrkAdapter of ISwapAdapter<ContractState> {
        fn swap(
            self: @ContractState,
            exchange_address: ContractAddress,
            token_from_address: ContractAddress,
            token_from_amount: u256,
            token_to_address: ContractAddress,
            token_to_min_amount: u256,
            to: ContractAddress,
            additional_swap_params: Array<felt252>,
        ) {
            assert(additional_swap_params.len() == 0, 'Invalid swap params');
            let STRK_ADDRESS: ContractAddress = contract_address_const::<
                0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d
            >();
            assert(token_from_address == STRK_ADDRESS || token_to_address == STRK_ADDRESS, 'Invalid STRK address');
            if (token_from_address == STRK_ADDRESS) {
                IStrkDispatcher { contract_address: token_from_address }.lock_and_delegate(to, token_from_amount);
            } else {
                IVstrkDispatcher { contract_address: token_from_address }.unlock(token_from_amount);
            }
        }
    }
}
