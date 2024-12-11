use super::mock_erc20::{IERC20Dispatcher, IERC20DispatcherTrait};

#[starknet::contract]
pub mod MockEkubo {
    use avnu::adapters::ekubo_adapter::{Delta, IEkuboRouter, PoolKey, PoolPrice, SwapParameters, i129};

    use starknet::ContractAddress;
    use starknet::contract_address_const;

    #[storage]
    struct Storage {}

    #[abi(embed_v0)]
    impl RouterImpl of IEkuboRouter<ContractState> {
        fn swap(ref self: ContractState, pool_key: PoolKey, params: SwapParameters) -> Delta {
            assert(pool_key.token0 == contract_address_const::<0x1>(), 'Invalid token0');
            assert(pool_key.token1 == contract_address_const::<0x2>(), 'Invalid token1');
            assert(pool_key.fee == 0x3, 'Invalid fee');
            assert(pool_key.tick_spacing == 0x4, 'Invalid tick_spacing');
            assert(pool_key.extension == contract_address_const::<0x5>(), 'Invalid extension');
            Delta { amount0: i129 { mag: 0, sign: false }, amount1: i129 { mag: 0, sign: false } }
        }
        fn lock(ref self: ContractState, data: Array<felt252>) -> Array<felt252> {
            ArrayTrait::new()
        }
        fn get_pool_price(self: @ContractState, pool_key: PoolKey) -> PoolPrice {
            PoolPrice { sqrt_ratio: 0, tick: i129 { mag: 0, sign: false } }
        }
        fn withdraw(ref self: ContractState, token_address: ContractAddress, recipient: ContractAddress, amount: u128) {}
        fn pay(ref self: ContractState, token_address: ContractAddress) {}
    }
}

#[starknet::contract]
pub mod MockJediSwap {
    use avnu::adapters::jediswap_adapter::IJediSwapRouter;

    use starknet::ContractAddress;
    use starknet::contract_address_const;

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
    }
}

#[starknet::contract]
pub mod MockMySwap {
    use avnu::adapters::myswap_adapter::IMySwapRouter;
    use starknet::ContractAddress;

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
    use avnu::adapters::sithswap_adapter::{ISithSwapRouter, Route};

    use starknet::ContractAddress;
    use starknet::contract_address_const;

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
    use avnu::adapters::tenkswap_adapter::ITenkSwapRouter;
    use starknet::ContractAddress;
    use starknet::contract_address_const;

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

#[starknet::contract]
pub mod MockSwapAdapter {
    use avnu::adapters::ISwapAdapter;
    use starknet::{ContractAddress, get_contract_address};
    use super::{IERC20Dispatcher, IERC20DispatcherTrait};

    #[storage]
    struct Storage {}

    #[abi(embed_v0)]
    impl MockERC20Impl of ISwapAdapter<ContractState> {
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
            let caller = get_contract_address();
            IERC20Dispatcher { contract_address: token_from_address }.burn(caller, token_from_amount);
            IERC20Dispatcher { contract_address: token_to_address }.mint(caller, token_from_amount);
        }
    }
}
