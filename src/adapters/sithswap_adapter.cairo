use starknet::ContractAddress;

#[derive(Drop, Serde)]
pub struct Route {
    pub from_address: ContractAddress,
    pub to_address: ContractAddress,
    pub stable: felt252,
}

#[starknet::interface]
pub trait ISithSwapRouter<TContractState> {
    fn swapExactTokensForTokens(
        self: @TContractState, amount_in: u256, amount_out_min: u256, routes: Array<Route>, to: ContractAddress, deadline: u64,
    ) -> Array<u256>;
}

#[starknet::contract]
pub mod SithswapAdapter {
    use avnu::adapters::ISwapAdapter;
    use avnu_lib::interfaces::erc20::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::{ContractAddress, get_block_timestamp};
    use super::{ISithSwapRouterDispatcher, ISithSwapRouterDispatcherTrait, Route};

    #[storage]
    struct Storage {}

    #[abi(embed_v0)]
    impl SithswapAdapter of ISwapAdapter<ContractState> {
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
            assert(additional_swap_params.len() == 1, 'Invalid swap params');

            // Init routes
            let routes = array![Route { from_address: sell_token_address, to_address: buy_token_address, stable: *additional_swap_params[0] }];

            // Init deadline
            let block_timestamp = get_block_timestamp();
            let deadline = block_timestamp;

            IERC20Dispatcher { contract_address: sell_token_address }.approve(exchange_address, sell_token_amount);
            ISithSwapRouterDispatcher { contract_address: exchange_address }
                .swapExactTokensForTokens(sell_token_amount, buy_token_min_amount, routes, to, deadline);
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
