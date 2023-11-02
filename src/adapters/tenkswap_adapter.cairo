use starknet::ContractAddress;

#[derive(Drop, Serde)]
struct Route {
    from_address: ContractAddress,
    to_address: ContractAddress,
    stable: felt252,
}

#[starknet::interface]
trait ITenkSwapRouter<TContractState> {
    fn swapExactTokensForTokens(
        self: @TContractState,
        amountIn: u256,
        amountOutMin: u256,
        path: Array<ContractAddress>,
        to: ContractAddress,
        deadline: u64
    ) -> Array<u256>;
}

#[starknet::contract]
mod TenkswapAdapter {
    use avnu::adapters::ISwapAdapter;
    use avnu::interfaces::erc20::{IERC20Dispatcher, IERC20DispatcherTrait};
    use super::{ITenkSwapRouterDispatcher, ITenkSwapRouterDispatcherTrait};
    use starknet::{get_block_timestamp, ContractAddress};
    use array::ArrayTrait;
    use super::Route;

    #[storage]
    struct Storage {}

    #[external(v0)]
    impl TenkswapAdapter of ISwapAdapter<ContractState> {
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

            // Init path
            let path = array![token_from_address, token_to_address];

            // Init deadline
            let block_timestamp = get_block_timestamp();
            let deadline = block_timestamp;

            IERC20Dispatcher { contract_address: token_from_address }
                .approve(exchange_address, token_from_amount);
            ITenkSwapRouterDispatcher { contract_address: exchange_address }
                .swapExactTokensForTokens(
                    token_from_amount, token_to_min_amount, path, to, deadline
                );
        }
    }
}
