use starknet::ContractAddress;

#[derive(Copy, Drop, Serde)]
pub struct i129 {
    pub mag: u128,
    pub sign: bool,
}

#[inline(always)]
fn i129_eq(a: @i129, b: @i129) -> bool {
    (a.mag == b.mag) & ((a.sign == b.sign) | (*a.mag == 0))
}

impl i129PartialEq of PartialEq<i129> {
    fn eq(lhs: @i129, rhs: @i129) -> bool {
        i129_eq(lhs, rhs)
    }

    fn ne(lhs: @i129, rhs: @i129) -> bool {
        !i129_eq(lhs, rhs)
    }
}

#[derive(Copy, Drop, Serde)]
pub struct PoolKey {
    pub token0: ContractAddress,
    pub token1: ContractAddress,
    pub fee: u128,
    pub tick_spacing: u128,
    pub extension: ContractAddress,
}

#[derive(Copy, Drop, Serde)]
pub struct Delta {
    pub amount0: i129,
    pub amount1: i129,
}

#[derive(Copy, Drop, Serde, PartialEq)]
pub struct PoolPrice {
    // the current ratio, up to 192 bits
    pub sqrt_ratio: u256,
    // the current tick, up to 32 bits
    pub tick: i129,
}

#[derive(Copy, Drop, Serde)]
pub struct RouteNode {
    pool_key: PoolKey,
    sqrt_ratio_limit: u256,
    skip_ahead: u128,
}
#[derive(Copy, Drop, Serde, PartialEq)]
pub struct TokenAmount {
    token: ContractAddress,
    amount: i129,
}

#[starknet::interface]
pub trait IEkuboRouter<TContractState> {
    fn swap(ref self: TContractState, node: RouteNode, token_amount: TokenAmount) -> Delta;
    fn quote_swap(ref self: TContractState, node: RouteNode, token_amount: TokenAmount) -> Delta;
    fn clear(ref self: TContractState, token: ContractAddress) -> u256;
}

#[starknet::interface]
pub trait IEkuboCore<TContractState> {
    fn get_pool_price(self: @TContractState, pool_key: PoolKey) -> PoolPrice;
}

#[starknet::contract]
pub mod EkuboAdapter {
    use avnu::adapters::ISwapAdapter;
    use avnu::math::sqrt_ratio::compute_sqrt_ratio_limit;
    use avnu_lib::interfaces::erc20::{IERC20Dispatcher, IERC20DispatcherTrait};
    #[feature("deprecated-starknet-consts")]
    use starknet::{ContractAddress, contract_address_const};
    use super::{
        IEkuboCoreDispatcher, IEkuboCoreDispatcherTrait, IEkuboRouterDispatcher, IEkuboRouterDispatcherTrait, PoolKey, RouteNode, TokenAmount, i129,
    };

    const MIN_SQRT_RATIO: u256 = 18446748437148339061;
    const MAX_SQRT_RATIO: u256 = 6277100250585753475930931601400621808602321654880405518632;
    //const ROUTER_ADDRESS: felt252 = 0x0045f933adf0607292468ad1c1dedaa74d5ad166392590e72676a34d01d7b763; // Sepolia
    const ROUTER_ADDRESS: felt252 = 0x0199741822c2dc722f6f605204f35e56dbc23bceed54818168c4c49e4fb8737e; // Mainnet

    #[storage]
    struct Storage {}

    #[derive(Drop, Copy, Serde)]
    struct SwapAfterLockParameters {
        contract_address: ContractAddress,
        to: ContractAddress,
        sell_token_address: ContractAddress,
        sell_token_amount: u256,
        buy_token_address: ContractAddress,
        pool_key: PoolKey,
        sqrt_ratio_distance: u256,
    }

    #[abi(embed_v0)]
    impl EkuboAdapter of ISwapAdapter<ContractState> {
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
            assert(additional_swap_params.len() == 6, 'Invalid swap params');

            // Prepare swap params
            let router_address = contract_address_const::<ROUTER_ADDRESS>();
            let pool_key = PoolKey {
                token0: (*additional_swap_params[0]).try_into().unwrap(),
                token1: (*additional_swap_params[1]).try_into().unwrap(),
                fee: (*additional_swap_params[2]).try_into().unwrap(),
                tick_spacing: (*additional_swap_params[3]).try_into().unwrap(),
                extension: (*additional_swap_params[4]).try_into().unwrap(),
            };
            let sqrt_ratio_distance: u256 = (*additional_swap_params[5]).into();
            let is_token1 = pool_key.token1 == sell_token_address;
            let pool_price = IEkuboCoreDispatcher { contract_address: exchange_address }.get_pool_price(pool_key);
            let sqrt_ratio_limit = compute_sqrt_ratio_limit(pool_price.sqrt_ratio, sqrt_ratio_distance, is_token1, MIN_SQRT_RATIO, MAX_SQRT_RATIO);
            let route_node = RouteNode { pool_key, sqrt_ratio_limit, skip_ahead: 100 };
            assert(sell_token_amount.high == 0, 'Overflow: Unsupported amount');
            let token_amount = TokenAmount { token: sell_token_address, amount: i129 { mag: sell_token_amount.low, sign: false } };

            // Transfer
            IERC20Dispatcher { contract_address: sell_token_address }.transfer(router_address, sell_token_amount);

            // Swap
            let router = IEkuboRouterDispatcher { contract_address: router_address };
            router.swap(route_node, token_amount);
            router.clear(buy_token_address);
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
            // Verify additional_swap_params
            assert(additional_swap_params.len() == 6, 'Invalid swap params');

            // Prepare swap params
            let router_address = contract_address_const::<ROUTER_ADDRESS>();
            let pool_key = PoolKey {
                token0: (*additional_swap_params[0]).try_into().unwrap(),
                token1: (*additional_swap_params[1]).try_into().unwrap(),
                fee: (*additional_swap_params[2]).try_into().unwrap(),
                tick_spacing: (*additional_swap_params[3]).try_into().unwrap(),
                extension: (*additional_swap_params[4]).try_into().unwrap(),
            };
            let sqrt_ratio_distance: u256 = (*additional_swap_params[5]).into();
            let is_token1 = pool_key.token1 == sell_token_address;
            let pool_price = IEkuboCoreDispatcher { contract_address: exchange_address }.get_pool_price(pool_key);
            let sqrt_ratio_limit = compute_sqrt_ratio_limit(pool_price.sqrt_ratio, sqrt_ratio_distance, is_token1, MIN_SQRT_RATIO, MAX_SQRT_RATIO);
            let route_node = RouteNode { pool_key, sqrt_ratio_limit, skip_ahead: 100 };
            assert(sell_token_amount.high == 0, 'Overflow: Unsupported amount');
            let token_amount = TokenAmount { token: sell_token_address, amount: i129 { mag: sell_token_amount.low, sign: false } };

            // Swap
            let router = IEkuboRouterDispatcher { contract_address: router_address };
            let delta = router.quote_swap(route_node, token_amount);

            if is_token1 {
                return u256 { high: 0, low: delta.amount0.mag };
            } else {
                return u256 { high: 0, low: delta.amount1.mag };
            }
        }
    }
}

