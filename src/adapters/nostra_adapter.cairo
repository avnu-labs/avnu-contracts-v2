use starknet::ContractAddress;

#[starknet::interface]
pub trait INostraRouter<TContractState> {
    fn swap_exact_tokens_for_tokens(
        self: @TContractState, amount_in: u256, amount_out_min: u256, path: Span<ContractAddress>, to: ContractAddress, deadline: u64,
    ) -> Array<u256>;
}

#[starknet::contract]
pub mod NostraAdapter {
    use avnu::adapters::ISwapAdapter;
    use avnu_lib::interfaces::erc20::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::{ContractAddress, get_block_timestamp};
    use super::{INostraRouterDispatcher, INostraRouterDispatcherTrait};

    #[storage]
    struct Storage {}

    #[abi(embed_v0)]
    impl NostraAdapter of ISwapAdapter<ContractState> {
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

            // Init path
            let path = array![sell_token_address, buy_token_address];

            // Init deadline
            let block_timestamp = get_block_timestamp();
            let deadline = block_timestamp;

            IERC20Dispatcher { contract_address: sell_token_address }.approve(exchange_address, sell_token_amount);
            INostraRouterDispatcher { contract_address: exchange_address }
                .swap_exact_tokens_for_tokens(sell_token_amount, buy_token_min_amount, path.span(), to, deadline);
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
