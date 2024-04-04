use starknet::ContractAddress;

#[derive(Copy, Drop, Serde, PartialEq)]
struct SwapResult {
    amount_in: u256,
    zero_for_one: bool,
    amount_out: u256,
    exact_input: bool
}

#[starknet::interface]
trait IHaikoRouter<TContractState> {
    fn curr_sqrt_price(self: @TContractState, market_id: felt252) -> u256;
    fn base_token(self: @TContractState, market_id: felt252) -> felt252;
    fn swap(
        self: @TContractState,
        market_id: felt252,
        is_buy: bool,
        amount: u256,
        exact_input: bool,
        threshold_sqrt_price: Option<u256>,
        threshold_amount: Option<u256>,
        deadline: Option<u64>
    ) -> SwapResult;
}

#[starknet::contract]
mod HaikoAdapter {
    use array::ArrayTrait;
    use avnu::adapters::ISwapAdapter;
    use avnu::interfaces::erc20::{IERC20Dispatcher, IERC20DispatcherTrait};
    use avnu::math::sqrt_ratio::compute_sqrt_ratio_limit;
    use starknet::{get_block_timestamp, ContractAddress};
    use super::{IHaikoRouterDispatcher, IHaikoRouterDispatcherTrait, SwapResult};
    use traits::Into;

    const MIN_SQRT_RATIO: u256 = 67774731328;
    const MAX_SQRT_RATIO: u256 = 1475476155217232889259591669213284373330197463;

    #[storage]
    struct Storage {}

    #[external(v0)]
    impl HaikoAdapter of ISwapAdapter<ContractState> {
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
            // Verify additional_swap_params
            assert(additional_swap_params.len() == 2, 'Invalid swap params');

            // Prepare swap params
            let sphinx = IHaikoRouterDispatcher { contract_address: exchange_address };
            let market_id = *additional_swap_params[0];
            let sqrt_ratio_distance: u256 = (*additional_swap_params[1]).into();
            let is_buy = sphinx.base_token(market_id) == token_to_address.into();
            let sqrt_price = sphinx.curr_sqrt_price(market_id);
            let sqrt_ratio_limit = compute_sqrt_ratio_limit(
                sqrt_price, sqrt_ratio_distance, is_buy, MIN_SQRT_RATIO, MAX_SQRT_RATIO
            );
            let deadline = get_block_timestamp();

            // Approve
            IERC20Dispatcher { contract_address: token_from_address }
                .approve(exchange_address, token_from_amount);

            // Swap
            sphinx
                .swap(
                    market_id,
                    is_buy,
                    token_from_amount,
                    true,
                    Option::Some(sqrt_ratio_limit),
                    Option::None,
                    Option::Some(deadline)
                );
        }
    }
}
