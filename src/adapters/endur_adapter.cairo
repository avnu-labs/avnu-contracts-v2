use starknet::ContractAddress;

#[starknet::interface]
pub trait IEndurLst<TContractState> {
    fn deposit_with_referral(
        self: @TContractState, assets: u256, receiver: ContractAddress, referral: ByteArray
    ) -> u256;
}

#[starknet::contract]
pub mod EndurAdapter {
    use avnu::adapters::ISwapAdapter;
    use avnu_lib::interfaces::erc20::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::{ContractAddress, get_block_timestamp};
    use super::{IEndurLstDispatcher, IEndurLstDispatcherTrait};

    #[storage]
    struct Storage {}

    #[abi(embed_v0)]
    impl EndurAdapter of ISwapAdapter<ContractState> {
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

            IERC20Dispatcher { contract_address: sell_token_address }.approve(buy_token_address, sell_token_amount);
            IEndurLstDispatcher { contract_address: buy_token_address }.deposit_with_referral(sell_token_amount,  to, "9F757");
        }
    }
}