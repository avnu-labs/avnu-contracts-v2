use starknet::ContractAddress;

#[starknet::interface]
pub trait IJediSwapRouter<TContractState> {
    fn swap_exact_tokens_for_tokens(
        self: @TContractState, amountIn: u256, amountOutMin: u256, path: Array<ContractAddress>, to: ContractAddress, deadline: u64,
    ) -> Array<u256>;
}

#[starknet::contract]
pub mod JediswapAdapter {
    use avnu::adapters::ISwapAdapter;
    use avnu_lib::interfaces::erc20::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::{ContractAddress, get_block_timestamp};
    use super::{IJediSwapRouterDispatcher, IJediSwapRouterDispatcherTrait};

    #[storage]
    struct Storage {}

    #[abi(embed_v0)]
    impl JediswapAdapter of ISwapAdapter<ContractState> {
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

            IERC20Dispatcher { contract_address: token_from_address }.approve(exchange_address, token_from_amount);
            IJediSwapRouterDispatcher { contract_address: exchange_address }
                .swap_exact_tokens_for_tokens(token_from_amount, token_to_min_amount, path, to, deadline);
        }
    }
}
