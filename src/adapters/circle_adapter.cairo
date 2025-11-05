#[starknet::interface]
pub trait ITokenMigration<TContractState> {
    fn swap_to_new(ref self: TContractState, amount: u256);
}

#[starknet::contract]
pub mod CircleAdapter {
    use avnu::adapters::ISwapAdapter;
    use avnu_lib::interfaces::erc20::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::ContractAddress;
    use super::{ITokenMigrationDispatcher, ITokenMigrationDispatcherTrait};

    #[storage]
    struct Storage {}

    #[abi(embed_v0)]
    impl CircleAdapter of ISwapAdapter<ContractState> {
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

            IERC20Dispatcher { contract_address: sell_token_address }.approve(exchange_address, sell_token_amount);
            ITokenMigrationDispatcher { contract_address: exchange_address }.swap_to_new(sell_token_amount);
        }

        fn quote(
            self: @ContractState,
            exchange_address: ContractAddress,
            sell_token_address: ContractAddress,
            sell_token_amount: u256,
            buy_token_address: ContractAddress,
            to: ContractAddress,
            additional_swap_params: Array<felt252>,
        ) -> u256 {
            0
        }
    }
}
