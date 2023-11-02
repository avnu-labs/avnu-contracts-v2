use starknet::ContractAddress;

#[derive(Drop, Serde)]
struct Route {
    from_address: ContractAddress,
    to_address: ContractAddress,
    stable: felt252,
}

#[starknet::interface]
trait ISithSwapRouter<TContractState> {
    fn swapExactTokensForTokens(
        self: @TContractState,
        amount_in: u256,
        amount_out_min: u256,
        routes: Array<Route>,
        to: ContractAddress,
        deadline: u64,
    ) -> Array<u256>;
}

#[starknet::contract]
mod SithswapAdapter {
    use avnu::adapters::ISwapAdapter;
    use avnu::interfaces::erc20::{IERC20Dispatcher, IERC20DispatcherTrait};
    use super::{ISithSwapRouterDispatcher, ISithSwapRouterDispatcherTrait};
    use starknet::{get_block_timestamp, ContractAddress};
    use array::ArrayTrait;
    use super::Route;

    #[storage]
    struct Storage {}

    #[external(v0)]
    impl SithswapAdapter of ISwapAdapter<ContractState> {
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
            assert(additional_swap_params.len() == 1, 'Invalid swap params');

            // Init routes
            let routes = array![
                Route {
                    from_address: token_from_address,
                    to_address: token_to_address,
                    stable: *additional_swap_params[0]
                }
            ];

            // Init deadline
            let block_timestamp = get_block_timestamp();
            let deadline = block_timestamp;

            IERC20Dispatcher { contract_address: token_from_address }
                .approve(exchange_address, token_from_amount);
            ISithSwapRouterDispatcher { contract_address: exchange_address }
                .swapExactTokensForTokens(
                    token_from_amount, token_to_min_amount, routes, to, deadline
                );
        }
    }
}
