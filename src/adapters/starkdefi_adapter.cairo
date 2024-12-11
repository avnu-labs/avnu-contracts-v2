use starknet::ContractAddress;

#[derive(Copy, Drop, Serde)]
struct SwapPath {
    tokenIn: ContractAddress,
    tokenOut: ContractAddress,
    stable: bool,
    feeTier: u8,
}

#[starknet::interface]
pub trait IStarkDefiRouter<TContractState> {
    fn swap_exact_tokens_for_tokens(
        self: @TContractState, amountIn: u256, amountOutMin: u256, path: Array<SwapPath>, to: ContractAddress, deadline: u64,
    ) -> Array<u256>;
}

#[starknet::contract]
pub mod StarkDefiAdapter {
    use avnu::adapters::ISwapAdapter;
    use avnu::interfaces::erc20::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::{ContractAddress, get_block_timestamp};
    use super::{IStarkDefiRouterDispatcher, IStarkDefiRouterDispatcherTrait, SwapPath};

    #[storage]
    struct Storage {}

    #[abi(embed_v0)]
    impl StarkDefiAdapter of ISwapAdapter<ContractState> {
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
            assert(additional_swap_params.len() == 2, 'Invalid swap params');

            // Init path
            let stable: bool = *additional_swap_params[0] == 1;
            let feeTier: u8 = (*additional_swap_params[1]).try_into().unwrap();
            let path = array![SwapPath { tokenIn: token_from_address, tokenOut: token_to_address, stable, feeTier }];

            // Init deadline
            let deadline = get_block_timestamp();

            IERC20Dispatcher { contract_address: token_from_address }.approve(exchange_address, token_from_amount);
            IStarkDefiRouterDispatcher { contract_address: exchange_address }
                .swap_exact_tokens_for_tokens(token_from_amount, token_to_min_amount, path, to, deadline);
        }
    }
}
