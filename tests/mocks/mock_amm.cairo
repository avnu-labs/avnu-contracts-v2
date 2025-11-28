use avnu::adapters::ISwapAdapter;
use avnu::adapters::jediswap_adapter::IJediSwapRouter;
use avnu::adapters::myswap_adapter::IMySwapRouter;
use avnu::adapters::sithswap_adapter::{ISithSwapRouter, Route};
use avnu::adapters::tenkswap_adapter::ITenkSwapRouter;
use avnu_lib::math::muldiv::muldiv;
#[feature("deprecated-starknet-consts")]
use starknet::{ContractAddress, contract_address_const, get_contract_address};
use super::mock_erc20::{IERC20Dispatcher, IERC20DispatcherTrait};

#[starknet::contract]
pub mod MockJediSwap {
    use super::*;

    #[storage]
    struct Storage {}

    #[abi(embed_v0)]
    impl MockERC20Impl of IJediSwapRouter<ContractState> {
        fn swap_exact_tokens_for_tokens(
            self: @ContractState, amountIn: u256, amountOutMin: u256, path: Array<ContractAddress>, to: ContractAddress, deadline: u64,
        ) -> Array<u256> {
            assert(amountIn == u256 { low: 1, high: 0 }, 'invalid amountIn');
            assert(amountOutMin == u256 { low: 2, high: 0 }, 'invalid amountOutMin');
            assert(path.len() == 2, 'invalid path');
            assert(to == contract_address_const::<0x4>(), 'invalid to');
            let mut amounts = ArrayTrait::new();
            amounts.append(u256 { low: 1, high: 0 });
            amounts
        }

        fn get_amounts_out(self: @ContractState, amountIn: u256, path: Array<ContractAddress>) -> Array<u256> {
            assert(amountIn == u256 { low: 1, high: 0 }, 'invalid amountIn');
            assert(path.len() == 2, 'invalid path');
            let mut amounts = ArrayTrait::new();
            amounts.append(u256 { low: 1, high: 0 });
            amounts
        }
    }
}

#[starknet::contract]
pub mod MockMySwap {
    use super::*;

    #[storage]
    struct Storage {}

    #[abi(embed_v0)]
    impl MockERC20Impl of IMySwapRouter<ContractState> {
        fn swap(self: @ContractState, pool_id: felt252, token_from_addr: ContractAddress, amount_from: u256, amount_to_min: u256) -> u256 {
            assert(pool_id == 0x9, 'invalid pool id');
            assert(amount_from == u256 { low: 1, high: 0 }, 'invalid amountIn');
            assert(amount_to_min == u256 { low: 2, high: 0 }, 'invalid amountOutMin');
            amount_to_min
        }
    }
}

#[starknet::contract]
pub mod MockSithSwap {
    use super::*;

    #[storage]
    struct Storage {}

    #[abi(embed_v0)]
    impl MockERC20Impl of ISithSwapRouter<ContractState> {
        fn swapExactTokensForTokens(
            self: @ContractState, amount_in: u256, amount_out_min: u256, routes: Array<Route>, to: ContractAddress, deadline: u64,
        ) -> Array<u256> {
            assert(amount_in == u256 { low: 1, high: 0 }, 'invalid amountIn');
            assert(amount_out_min == u256 { low: 2, high: 0 }, 'invalid amountOutMin');
            assert(routes.len() == 1, 'invalid routes');
            assert(routes.at(0).stable == @0x1, 'invalid stable');
            assert(to == contract_address_const::<0x4>(), 'invalid to');
            let mut amounts = ArrayTrait::new();
            amounts.append(u256 { low: 1, high: 0 });
            amounts
        }
    }
}

#[starknet::contract]
pub mod MockTenkSwap {
    use super::*;

    #[storage]
    struct Storage {}

    #[abi(embed_v0)]
    impl MockERC20Impl of ITenkSwapRouter<ContractState> {
        fn swapExactTokensForTokens(
            self: @ContractState, amountIn: u256, amountOutMin: u256, path: Array<ContractAddress>, to: ContractAddress, deadline: u64,
        ) -> Array<u256> {
            assert(amountIn == u256 { low: 1, high: 0 }, 'invalid amountIn');
            assert(amountOutMin == u256 { low: 2, high: 0 }, 'invalid amountOutMin');
            assert(path.len() == 2, 'invalid path');
            assert(to == contract_address_const::<0x4>(), 'invalid to');
            let mut amounts = ArrayTrait::new();
            amounts.append(u256 { low: 1, high: 0 });
            amounts
        }
    }
}

pub trait IMockPriceFunction<T> {
    fn price(self: @T, amount_in: u256) -> u256;
}

#[derive(Debug, Serde, Clone, Drop)]
pub enum MockPriceFunction {
    Constant: MockConstantPriceFunction,
    UniV2: MockUniV2PriceFunction,
}

impl IMockPriceFunctionImpl of IMockPriceFunction<MockPriceFunction> {
    fn price(self: @MockPriceFunction, amount_in: u256) -> u256 {
        match self {
            MockPriceFunction::Constant(x) => x.price(amount_in),
            MockPriceFunction::UniV2(x) => x.price(amount_in),
        }
    }
}

#[derive(Debug, Serde, Clone, Drop)]
pub struct MockConstantPriceFunction {
    pub price: u256,
}

impl IMockConstantPriceFunctionImpl of IMockPriceFunction<MockConstantPriceFunction> {
    fn price(self: @MockConstantPriceFunction, amount_in: u256) -> u256 {
        *self.price
    }
}

#[derive(Debug, Serde, Clone, Drop)]
pub struct MockUniV2PriceFunction {
    pub reserve_a: u256,
    pub reserve_b: u256,
}

impl IMockUniV2PriceFunctionImpl of IMockPriceFunction<MockUniV2PriceFunction> {
    fn price(self: @MockUniV2PriceFunction, amount_in: u256) -> u256 {
        let (result, _) = muldiv(*self.reserve_b, 18446744073709551616, *self.reserve_a + amount_in, false);

        result
    }
}

#[starknet::contract]
pub mod MockSwapAdapter {
    use super::*;

    #[storage]
    struct Storage {}

    #[abi(embed_v0)]
    impl MockERC20Impl of ISwapAdapter<ContractState> {
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
            let caller = get_contract_address();
            let buy_token_amount = self.quote(exchange_address, sell_token_address, sell_token_amount, buy_token_address, to, additional_swap_params);

            IERC20Dispatcher { contract_address: sell_token_address }.burn(caller, sell_token_amount);
            IERC20Dispatcher { contract_address: buy_token_address }.mint(caller, buy_token_amount);
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
            let mut params = additional_swap_params.clone().span();
            let price_function: MockPriceFunction = Serde::deserialize(ref params)
                .unwrap_or(MockPriceFunction::Constant(MockConstantPriceFunction { price: 18446744073709551616 }));

            let price = price_function.price(sell_token_amount);
            let (buy_token_amount, _) = muldiv(sell_token_amount, price, 18446744073709551616, false);

            buy_token_amount
        }
    }
}
