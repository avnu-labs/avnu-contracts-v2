use starknet::ContractAddress;

#[derive(Copy, Drop, Serde, PartialEq)]
pub struct SwapResult {
    amount_in: u256,
    zero_for_one: bool,
    amount_out: u256,
    exact_input: bool,
}

#[starknet::interface]
pub trait IMySwapV2Router<TContractState> {
    fn current_sqrt_price(self: @TContractState, pool_key: felt252) -> u256;
    fn token0(self: @TContractState, pool_key: felt252) -> ContractAddress;
    fn swap(self: @TContractState, pool_key: felt252, zero_for_one: bool, amount: u256, exact_input: bool, sqrt_price_limit_x96: u256) -> SwapResult;
}

#[starknet::contract]
pub mod MyswapV2Adapter {
    use avnu::adapters::ISwapAdapter;
    use avnu::math::sqrt_ratio::compute_sqrt_ratio_limit;
    use avnu_lib::interfaces::erc20::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::ContractAddress;
    use super::{IMySwapV2RouterDispatcher, IMySwapV2RouterDispatcherTrait};

    // 4295128739 + 1
    const MIN_SQRT_RATIO: u256 = 4295128740;
    // 1461446703485210103287273052203988822378723970342 - 1
    const MAX_SQRT_RATIO: u256 = 1461446703485210103287273052203988822378723970341;

    #[storage]
    struct Storage {}

    #[abi(embed_v0)]
    impl MyswapV2Adapter of ISwapAdapter<ContractState> {
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
            // Verify additional_swap_params
            assert(additional_swap_params.len() == 2, 'Invalid swap params');

            // Prepare swap params
            let myswapv2 = IMySwapV2RouterDispatcher { contract_address: exchange_address };
            let pool_key = *additional_swap_params[0];
            let sqrt_ratio_distance: u256 = (*additional_swap_params[1]).into();
            let is_token_0 = myswapv2.token0(pool_key) == sell_token_address;
            let sqrt_price = myswapv2.current_sqrt_price(pool_key);
            let sqrt_ratio_limit = compute_sqrt_ratio_limit(sqrt_price, sqrt_ratio_distance, !is_token_0, MIN_SQRT_RATIO, MAX_SQRT_RATIO);

            // Approve
            IERC20Dispatcher { contract_address: sell_token_address }.approve(exchange_address, sell_token_amount);

            // Swap
            myswapv2.swap(pool_key, is_token_0, sell_token_amount, true, sqrt_ratio_limit);
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
