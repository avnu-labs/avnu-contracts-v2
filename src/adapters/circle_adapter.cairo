use starknet::ContractAddress;

#[starknet::interface]
pub trait ITokenMigration<TContractState> {
    fn get_legacy_token(self: @TContractState) -> ContractAddress;
    fn swap_to_new(ref self: TContractState, amount: u256);
    fn swap_to_legacy(ref self: TContractState, amount: u256);
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
            let token_migration = ITokenMigrationDispatcher { contract_address: exchange_address };
            let legacy_token_address = token_migration.get_legacy_token();

            IERC20Dispatcher { contract_address: sell_token_address }.approve(exchange_address, sell_token_amount);
            match sell_token_address == legacy_token_address {
                true => token_migration.swap_to_new(sell_token_amount),
                false => token_migration.swap_to_legacy(sell_token_amount),
            }
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
