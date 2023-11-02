#[starknet::contract]
mod MockEkubo {
    use avnu::adapters::ekubo_adapter::{
        IEkuboRouter, PoolPrice, CallPoints, Delta, PoolKey, SwapParameters, i129
    };
    use starknet::contract_address_const;
    use array::ArrayTrait;

    use starknet::{ContractAddress, get_caller_address};

    #[storage]
    struct Storage {}

    #[external(v0)]
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
            PoolPrice {
                sqrt_ratio: 0,
                tick: i129 { mag: 0, sign: false },
                call_points: CallPoints {
                    after_initialize_pool: false,
                    before_swap: false,
                    after_swap: false,
                    before_update_position: false,
                    after_update_position: false,
                }
            }
        }
        fn withdraw(
            ref self: ContractState,
            token_address: ContractAddress,
            recipient: ContractAddress,
            amount: u128
        ) {}
        fn deposit(ref self: ContractState, token_address: ContractAddress) -> u128 {
            0
        }
    }
}

#[starknet::contract]
mod MockJediSwap {
    use avnu::adapters::jediswap_adapter::IJediSwapRouter;
    use starknet::contract_address_const;
    use array::ArrayTrait;

    use starknet::{ContractAddress, get_caller_address};

    #[storage]
    struct Storage {}

    #[external(v0)]
    impl MockERC20Impl of IJediSwapRouter<ContractState> {
        fn swap_exact_tokens_for_tokens(
            self: @ContractState,
            amountIn: u256,
            amountOutMin: u256,
            path: Array<ContractAddress>,
            to: ContractAddress,
            deadline: u64
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
mod MockMySwap {
    use avnu::adapters::myswap_adapter::IMySwapRouter;
    use starknet::contract_address_const;
    use array::ArrayTrait;

    use starknet::{ContractAddress, get_caller_address};

    #[storage]
    struct Storage {}

    #[external(v0)]
    impl MockERC20Impl of IMySwapRouter<ContractState> {
        fn swap(
            self: @ContractState,
            pool_id: felt252,
            token_from_addr: ContractAddress,
            amount_from: u256,
            amount_to_min: u256
        ) -> u256 {
            assert(pool_id == 0x9, 'invalid pool id');
            assert(amount_from == u256 { low: 1, high: 0 }, 'invalid amountIn');
            assert(amount_to_min == u256 { low: 2, high: 0 }, 'invalid amountOutMin');
            amount_to_min
        }
    }
}

#[starknet::contract]
mod MockSithSwap {
    use avnu::adapters::sithswap_adapter::{ISithSwapRouter, Route};
    use starknet::contract_address_const;
    use array::ArrayTrait;

    use starknet::{ContractAddress, get_caller_address};

    #[storage]
    struct Storage {}

    #[external(v0)]
    impl MockERC20Impl of ISithSwapRouter<ContractState> {
        fn swapExactTokensForTokens(
            self: @ContractState,
            amount_in: u256,
            amount_out_min: u256,
            routes: Array<Route>,
            to: ContractAddress,
            deadline: u64,
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
mod MockTenkSwap {
    use avnu::adapters::tenkswap_adapter::{ITenkSwapRouter, Route};
    use starknet::contract_address_const;
    use array::ArrayTrait;

    use starknet::{ContractAddress, get_caller_address};

    #[storage]
    struct Storage {}

    #[external(v0)]
    impl MockERC20Impl of ITenkSwapRouter<ContractState> {
        fn swapExactTokensForTokens(
            self: @ContractState,
            amountIn: u256,
            amountOutMin: u256,
            path: Array<ContractAddress>,
            to: ContractAddress,
            deadline: u64
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
mod MockSwapAdapter {
    use avnu::adapters::ISwapAdapter;
    use avnu::tests::mocks::mock_erc20::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::{ContractAddress, get_contract_address};

    #[storage]
    struct Storage {}

    #[external(v0)]
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
            IERC20Dispatcher { contract_address: token_from_address }
                .burn(caller, token_from_amount);
            IERC20Dispatcher { contract_address: token_to_address }.mint(caller, token_from_amount);
        }
    }
}
