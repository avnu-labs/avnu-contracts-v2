use starknet::ContractAddress;

#[starknet::interface]
pub trait IVstrk<TContractState> {
    fn unlock(self: @TContractState, amount: u256);
}
#[starknet::interface]
pub trait IStrk<TContractState> {
    fn lock_and_delegate(self: @TContractState, delegatee: ContractAddress, amount: u256);
}

#[starknet::contract]
pub mod VstrkAdapter {
    use avnu::adapters::ISwapAdapter;
    use starknet::{ContractAddress, contract_address_const};
    use super::{IStrkDispatcher, IStrkDispatcherTrait, IVstrkDispatcher, IVstrkDispatcherTrait};

    #[storage]
    struct Storage {}

    #[abi(embed_v0)]
    impl VstrkAdapter of ISwapAdapter<ContractState> {
        fn swap(
            self: @ContractState,
            exchange_address: ContractAddress,
            sell_token_address: ContractAddress,
            sell_token_amount: u256,
            buy_token_address: ContractAddress,
            buy_token_min_amount: u256,
            to: ContractAddress,
            additional_swap_params: Array<felt252>,
        ) {
            assert(additional_swap_params.len() == 0, 'Invalid swap params');
            let STRK_ADDRESS: ContractAddress = contract_address_const::<0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d>();
            assert(sell_token_address == STRK_ADDRESS || buy_token_address == STRK_ADDRESS, 'Invalid STRK address');
            if (sell_token_address == STRK_ADDRESS) {
                IStrkDispatcher { contract_address: sell_token_address }.lock_and_delegate(to, sell_token_amount);
            } else {
                IVstrkDispatcher { contract_address: sell_token_address }.unlock(sell_token_amount);
            }
        }

        fn quote(
            self: @ContractState,
            exchange_address: ContractAddress,
            sell_token_address: ContractAddress,
            sell_token_amount: u256,
            buy_token_address: ContractAddress,
            buy_token_min_amount: u256,
            to: ContractAddress,
            additional_swap_params: Array<felt252>,
        ) -> Option<u256> {
            Option::None
        }
    }
}
