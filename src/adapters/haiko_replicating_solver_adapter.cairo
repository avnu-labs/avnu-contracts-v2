use starknet::ContractAddress;

#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct MarketInfo {
    pub base_token: ContractAddress,
    pub quote_token: ContractAddress,
    pub owner: ContractAddress,
    pub is_public: bool,
}

#[derive(Copy, Drop, Serde)]
pub struct SwapParams {
    pub is_buy: bool,
    pub amount: u256,
    pub exact_input: bool,
    pub threshold_sqrt_price: Option<u256>,
    pub threshold_amount: Option<u256>,
    pub deadline: Option<u64>,
}

#[derive(Copy, Drop, Serde)]
pub struct SwapAmounts {
    pub amount_in: u256,
    pub amount_out: u256,
    pub fees: u256,
}

#[starknet::interface]
pub trait IHaikoRouter<TContractState> {
    fn market_info(self: @TContractState, market_id: felt252) -> MarketInfo;
    fn swap(ref self: TContractState, market_id: felt252, swap_params: SwapParams) -> SwapAmounts;
}

#[starknet::contract]
pub mod HaikoReplicatingSolverAdapter {
    use avnu::adapters::ISwapAdapter;
    use avnu_lib::interfaces::erc20::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::{ContractAddress, get_block_timestamp};
    use super::{IHaikoRouterDispatcher, IHaikoRouterDispatcherTrait, SwapParams};

    #[storage]
    struct Storage {}

    #[abi(embed_v0)]
    impl HaikoReplicatingSolverAdapter of ISwapAdapter<ContractState> {
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
            assert(additional_swap_params.len() == 1, 'Invalid swap params');

            // Prepare swap params
            let haiko = IHaikoRouterDispatcher { contract_address: exchange_address };
            let market_id = *additional_swap_params[0];
            let is_buy = haiko.market_info(market_id).base_token == buy_token_address.into();
            let swap_params = SwapParams {
                is_buy,
                amount: sell_token_amount,
                exact_input: true,
                threshold_sqrt_price: Option::None,
                threshold_amount: Option::None,
                deadline: Option::Some(get_block_timestamp()),
            };

            // Approve
            IERC20Dispatcher { contract_address: sell_token_address }.approve(exchange_address, sell_token_amount);

            // Swap

            haiko.swap(market_id, swap_params);
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
