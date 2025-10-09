use avnu::models::Route;
use starknet::{ClassHash, ContractAddress};

#[starknet::interface]
pub trait IExchange<TContractState> {
    fn initialize(
        ref self: TContractState,
        owner: ContractAddress,
        fee_recipient: ContractAddress,
        fees_bps_0: u128,
        fees_bps_1: u128,
        swap_exact_token_to_fees_bps: u128,
    );
    fn get_adapter_class_hash(self: @TContractState, exchange_address: ContractAddress) -> ClassHash;
    fn set_adapter_class_hash(ref self: TContractState, exchange_address: ContractAddress, adapter_class_hash: ClassHash) -> bool;
    fn get_external_solver_adapter_class_hash(self: @TContractState, external_solver_address: ContractAddress) -> ClassHash;
    fn set_external_solver_adapter_class_hash(
        ref self: TContractState, external_solver_address: ContractAddress, adapter_class_hash: ClassHash,
    ) -> bool;
    fn multi_route_swap(
        ref self: TContractState,
        sell_token_address: ContractAddress,
        sell_token_amount: u256,
        buy_token_address: ContractAddress,
        buy_token_amount: u256,
        buy_token_min_amount: u256,
        beneficiary: ContractAddress,
        integrator_fee_amount_bps: u128,
        integrator_fee_recipient: ContractAddress,
        routes: Array<Route>,
    ) -> bool;
    fn swap_exact_token_to(
        ref self: TContractState,
        sell_token_address: ContractAddress,
        sell_token_amount: u256,
        sell_token_max_amount: u256,
        buy_token_address: ContractAddress,
        buy_token_amount: u256,
        beneficiary: ContractAddress,
        integrator_fee_amount_bps: u128,
        integrator_fee_recipient: ContractAddress,
        routes: Array<Route>,
    ) -> bool;
    fn swap_external_solver(
        ref self: TContractState,
        user_address: ContractAddress,
        sell_token_address: ContractAddress,
        buy_token_address: ContractAddress,
        beneficiary: ContractAddress,
        external_solver_address: ContractAddress,
        external_solver_adapter_calldata: Array<felt252>,
    ) -> bool;
}

#[starknet::contract]
pub mod Exchange {
    use avnu::adapters::{ISwapAdapterDispatcherTrait, ISwapAdapterLibraryDispatcher};
    use avnu::components::fee::{FeeComponent, FeePolicy};
    use avnu::external_solver_adapters::{IExternalSolverAdapterDispatcherTrait, IExternalSolverAdapterLibraryDispatcher};
    use avnu::interfaces::locker::{ILocker, ISwapAfterLockDispatcherTrait, ISwapAfterLockLibraryDispatcher};
    use avnu::models::{AlternativeSwap, BranchSwap, DirectSwap, Route, RouteSwap};
    use avnu_lib::components::ownable::OwnableComponent;
    use avnu_lib::components::upgradable::UpgradableComponent;
    use avnu_lib::interfaces::erc20::{IERC20Dispatcher, IERC20DispatcherTrait};
    use avnu_lib::math::muldiv::muldiv;
    use core::dict::Felt252Dict;
    use core::num::traits::Zero;
    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess};
    use starknet::{ClassHash, ContractAddress, get_caller_address, get_contract_address};
    use super::IExchange;

    // 100 * 10 ** 10 => (10 decimals)
    const MAX_ROUTE_PERCENT: u128 = 1000000000000;

    component!(path: FeeComponent, storage: fee, event: FeeEvent);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: UpgradableComponent, storage: upgradable, event: UpgradableEvent);

    #[abi(embed_v0)]
    impl FeeImpl = FeeComponent::FeeImpl<ContractState>;
    impl FeeInternalImpl = FeeComponent::FeeInternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::OwnableInternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl UpgradableImpl = UpgradableComponent::UpgradableImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        fee: FeeComponent::Storage,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        upgradable: UpgradableComponent::Storage,
        #[feature("deprecated_legacy_map")]
        AdapterClassHash: LegacyMap<ContractAddress, ClassHash>,
        external_solver_adapter: Map<ContractAddress, ClassHash>,
    }

    #[event]
    #[derive(starknet::Event, Drop, PartialEq)]
    pub enum Event {
        #[flat]
        FeeEvent: FeeComponent::Event,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        UpgradableEvent: UpgradableComponent::Event,
        Swap: Swap,
    }

    #[derive(Drop, starknet::Event, PartialEq)]
    pub struct Swap {
        pub taker_address: ContractAddress,
        pub sell_address: ContractAddress,
        pub sell_amount: u256,
        pub buy_address: ContractAddress,
        pub buy_amount: u256,
        pub beneficiary: ContractAddress,
    }

    #[abi(embed_v0)]
    impl ExchangeLocker of ILocker<ContractState> {
        fn locked(ref self: ContractState, id: u32, data: Array<felt252>) -> Array<felt252> {
            let caller_address = get_caller_address();
            let exchange_address = (*data[0]).try_into().unwrap();

            // Only allow exchange's contract to call this method.
            assert(caller_address == exchange_address, 'UNAUTHORIZED_CALLBACK');

            // Get adapter class hash
            // and verify that `exchange_address` is known
            // `swap_after_lock` cannot be called by unknown contract address
            let class_hash = self.get_adapter_class_hash(exchange_address);
            assert(!class_hash.is_zero(), 'Unknown exchange');

            // Call adapter to execute the swap
            let adapter_dispatcher = ISwapAfterLockLibraryDispatcher { class_hash };
            adapter_dispatcher.swap_after_lock(data);

            ArrayTrait::new()
        }
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        fee_recipient: ContractAddress,
        fees_bps_0: u128,
        fees_bps_1: u128,
        swap_exact_token_to_fees_bps: u128,
    ) {
        self.initialize(owner, fee_recipient, fees_bps_0, fees_bps_1, swap_exact_token_to_fees_bps);
    }

    #[abi(embed_v0)]
    impl Exchange of IExchange<ContractState> {
        // This is a public function meant to be called in a single multicall transaction right after the call to upgrade_class
        // It is guaranteed to run just once and hence is not gated behind assert_only_owner
        // This allows us to deploy a clean final contract in one go
        fn initialize(
            ref self: ContractState,
            owner: ContractAddress,
            fee_recipient: ContractAddress,
            fees_bps_0: u128,
            fees_bps_1: u128,
            swap_exact_token_to_fees_bps: u128,
        ) {
            // Due to this call to ownable.initialize, this initialize function inside Exchange contract
            // is guaranteed to run just once
            self.ownable.initialize(owner);

            // Not strictly required for migration - keeping it here for completeness since we have call to initialize in
            // the constructor
            self.fee.initialize(fee_recipient, fees_bps_0, fees_bps_1, swap_exact_token_to_fees_bps);
        }

        fn get_adapter_class_hash(self: @ContractState, exchange_address: ContractAddress) -> ClassHash {
            self.AdapterClassHash.read(exchange_address)
        }

        fn set_adapter_class_hash(ref self: ContractState, exchange_address: ContractAddress, adapter_class_hash: ClassHash) -> bool {
            self.ownable.assert_only_owner();
            self.AdapterClassHash.write(exchange_address, adapter_class_hash);
            true
        }

        fn get_external_solver_adapter_class_hash(self: @ContractState, external_solver_address: ContractAddress) -> ClassHash {
            self.external_solver_adapter.read(external_solver_address)
        }

        fn set_external_solver_adapter_class_hash(
            ref self: ContractState, external_solver_address: ContractAddress, adapter_class_hash: ClassHash,
        ) -> bool {
            self.ownable.assert_only_owner();
            self.external_solver_adapter.write(external_solver_address, adapter_class_hash);
            true
        }

        fn multi_route_swap(
            ref self: ContractState,
            sell_token_address: ContractAddress,
            sell_token_amount: u256,
            buy_token_address: ContractAddress,
            buy_token_amount: u256,
            buy_token_min_amount: u256,
            beneficiary: ContractAddress,
            integrator_fee_amount_bps: u128,
            integrator_fee_recipient: ContractAddress,
            routes: Array<Route>,
        ) -> bool {
            let caller_address = get_caller_address();
            let contract_address = get_contract_address();
            let sell_token = IERC20Dispatcher { contract_address: sell_token_address };
            let buy_token = IERC20Dispatcher { contract_address: buy_token_address };
            let routes_span = routes.span();

            // Execute all the pre-swap actions (some checks, retrieve token from...)
            self.before_swap(contract_address, caller_address, sell_token, sell_token_amount, buy_token, beneficiary, routes_span);

            // We retrieve the fee policy and our fee amount in bps
            let (fee_policy, fees_bps) = self
                .fee
                .get_fees(sell_token_address, buy_token_address, integrator_fee_recipient, integrator_fee_amount_bps, routes.len());
            // If fee policy is FeeOnSell, we collect the fees now
            if fee_policy == FeePolicy::FeeOnSell {
                self.fee.collect_fees(sell_token, sell_token_amount, fees_bps, integrator_fee_recipient, integrator_fee_amount_bps);
            }

            // Swap
            self.apply_routes(routes, contract_address);

            // If fee policy is FeeOnBuy, we collect the fees now
            let buy_token_final_amount = match fee_policy {
                FeePolicy::FeeOnBuy => {
                    let buy_token_amount_received = buy_token.balanceOf(contract_address);
                    self.fee.collect_fees(buy_token, buy_token_amount_received, fees_bps, integrator_fee_recipient, integrator_fee_amount_bps)
                },
                _ => buy_token.balanceOf(contract_address),
            };

            // Check amount of token to and transfer tokens
            assert(buy_token_min_amount <= buy_token_final_amount, 'Insufficient tokens received');
            buy_token.transfer(beneficiary, buy_token_final_amount);

            // Dict of bools are supported yet
            let mut checked_tokens: Felt252Dict<u64> = Default::default();
            // Token to has already been checked
            checked_tokens.insert(buy_token_address.into(), 1);
            self.assert_no_remaining_tokens(contract_address, routes_span, checked_tokens);

            // Emit event
            self
                .emit(
                    Swap {
                        taker_address: caller_address,
                        sell_address: sell_token.contract_address,
                        sell_amount: sell_token_amount,
                        buy_address: buy_token.contract_address,
                        buy_amount: buy_token_final_amount,
                        beneficiary: beneficiary,
                    },
                );

            true
        }

        fn swap_exact_token_to(
            ref self: ContractState,
            sell_token_address: ContractAddress,
            sell_token_amount: u256,
            sell_token_max_amount: u256,
            buy_token_address: ContractAddress,
            buy_token_amount: u256,
            beneficiary: ContractAddress,
            integrator_fee_amount_bps: u128,
            integrator_fee_recipient: ContractAddress,
            routes: Array<Route>,
        ) -> bool {
            let caller_address = get_caller_address();
            let contract_address = get_contract_address();
            let sell_token = IERC20Dispatcher { contract_address: sell_token_address };
            let buy_token = IERC20Dispatcher { contract_address: buy_token_address };
            let routes_span = routes.span();

            // Execute all the pre-swap actions (some checks, retrieve token from...)
            assert(sell_token_max_amount >= sell_token_amount, 'Invalid token from max amount');
            self.before_swap(contract_address, caller_address, sell_token, sell_token_amount, buy_token, beneficiary, routes_span);

            // We retrieve the fee policy
            let fee_policy = self.fee.get_fee_policy(sell_token_address, buy_token_address);
            let integrator_fee_amount = self
                .compute_swap_exact_token_to_integrator_fee_amount(
                    sell_token_amount, buy_token_amount, integrator_fee_recipient, integrator_fee_amount_bps, fee_policy,
                );

            // If fee policy is FeeOnSell, we collect the fees now, but only for the integrator
            if (!integrator_fee_amount.is_zero() && fee_policy == FeePolicy::FeeOnSell) {
                sell_token.transfer(integrator_fee_recipient, integrator_fee_amount);
            }

            // If fee policy is FeeOnBuy, the target buy token amount is increased with the integrator fee
            let internal_buy_token_amount = if (!integrator_fee_amount_bps.is_zero()
                && !integrator_fee_recipient.is_zero()
                && fee_policy == FeePolicy::FeeOnBuy) {
                buy_token_amount + integrator_fee_amount
            } else {
                buy_token_amount
            };

            // Swap
            let (sell_token_amount_used, buy_token_amount_received) = self
                ._swap_exact_token_to(
                    contract_address,
                    caller_address,
                    sell_token,
                    sell_token_amount,
                    sell_token_max_amount,
                    buy_token,
                    internal_buy_token_amount,
                    routes,
                );

            // Check amount of token to and transfer tokens
            assert(internal_buy_token_amount <= buy_token_amount_received, 'Insufficient tokens received');
            buy_token.transfer(beneficiary, buy_token_amount);

            // Collect integrator fees
            if (!integrator_fee_amount.is_zero() && fee_policy == FeePolicy::FeeOnBuy) {
                buy_token.transfer(integrator_fee_recipient, integrator_fee_amount);
            }

            // Collect fees
            let fees_amount = buy_token_amount_received - internal_buy_token_amount;
            if (fees_amount > 0) {
                let fees_recipient = self.fee.get_fees_recipient();
                assert(!fees_recipient.is_zero(), 'Fee recipient is empty');
                buy_token.transfer(fees_recipient, fees_amount);
            }

            // Emit event
            self
                .emit(
                    Swap {
                        taker_address: caller_address,
                        sell_address: sell_token_address,
                        sell_amount: sell_token_amount_used,
                        buy_address: buy_token_address,
                        buy_amount: buy_token_amount,
                        beneficiary: beneficiary,
                    },
                );

            // Dict of bools are supported yet
            let mut checked_tokens: Felt252Dict<u64> = Default::default();
            // Token to has already been checked
            checked_tokens.insert(buy_token_address.into(), 1);
            self.assert_no_remaining_tokens(contract_address, routes_span, checked_tokens);
            true
        }

        fn swap_external_solver(
            ref self: ContractState,
            user_address: ContractAddress,
            sell_token_address: ContractAddress,
            buy_token_address: ContractAddress,
            beneficiary: ContractAddress,
            external_solver_address: ContractAddress,
            external_solver_adapter_calldata: Array<felt252>,
        ) -> bool {
            // In the future, the beneficiary may not be the caller
            // Check if beneficiary == caller_address
            assert(beneficiary == user_address, 'Beneficiary is not the user');
            let adapter_class_hash = self.get_external_solver_adapter_class_hash(external_solver_address);
            assert(!adapter_class_hash.is_zero(), 'Unknown external solver');
            let response = IExternalSolverAdapterLibraryDispatcher { class_hash: adapter_class_hash }
                .swap(user_address, sell_token_address, buy_token_address, beneficiary, external_solver_adapter_calldata);
            self
                .emit(
                    Swap {
                        taker_address: user_address,
                        sell_address: sell_token_address,
                        sell_amount: response.sell_amount,
                        buy_address: buy_token_address,
                        buy_amount: response.buy_amount,
                        beneficiary: user_address,
                    },
                );
            true
        }
    }

    #[generate_trait]
    impl Internal of InternalTrait {
        fn before_swap(
            ref self: ContractState,
            contract_address: ContractAddress,
            caller_address: ContractAddress,
            sell_token: IERC20Dispatcher,
            sell_token_amount: u256,
            buy_token: IERC20Dispatcher,
            beneficiary: ContractAddress,
            routes: Span<Route>,
        ) {
            // In the future, the beneficiary may not be the caller
            // Check if beneficiary == caller_address
            assert(beneficiary == caller_address, 'Beneficiary is not the caller');

            // Transfer tokens to contract
            self.collect_sell_token(contract_address, caller_address, sell_token, sell_token_amount);

            // Check routes validity
            let route_len = routes.len();
            assert(route_len > 0, 'Routes is empty');
            let first_route: @Route = routes[0];
            let last_route: @Route = routes[route_len - 1];
            assert(*first_route.sell_token == sell_token.contract_address, 'Invalid token from');
            assert(*last_route.buy_token == buy_token.contract_address, 'Invalid token to');
        }

        fn collect_sell_token(
            ref self: ContractState,
            contract_address: ContractAddress,
            caller_address: ContractAddress,
            sell_token: IERC20Dispatcher,
            sell_token_amount: u256,
        ) {
            // Transfer tokens to contract
            assert(sell_token_amount > 0, 'Token from amount is 0');
            let sell_token_balance = sell_token.balanceOf(caller_address);
            assert(sell_token_balance >= sell_token_amount, 'Token from balance is too low');
            sell_token.transferFrom(caller_address, contract_address, sell_token_amount);
        }

        fn _swap_exact_token_to(
            ref self: ContractState,
            contract_address: ContractAddress,
            caller_address: ContractAddress,
            sell_token: IERC20Dispatcher,
            sell_token_amount: u256,
            sell_token_max_amount: u256,
            buy_token: IERC20Dispatcher,
            buy_token_amount: u256,
            routes: Array<Route>,
        ) -> (u256, u256) {
            // First, swap with 0% of slippage
            self.apply_routes(routes.clone(), contract_address);
            let mut sell_token_amount_used = sell_token_amount;
            let mut sell_token_last_amount_used = sell_token_amount;
            let mut remaining_sell_token_amount = sell_token_max_amount - sell_token_amount;
            let mut buy_token_amount_received = buy_token.balanceOf(contract_address);
            let mut buy_token_last_amount_received = buy_token_amount_received;

            let target_fees_bps = self.fee.get_swap_exact_token_to_fees_bps();
            let (fee_amount_target, overflows) = muldiv(buy_token_amount, target_fees_bps.into(), 10000_u256, false);
            assert(overflows == false, 'Overflow: Invalid fee');

            // While the buy_token_amount is not reached, we continue to add more sell_token
            let mut remaining_iterations = 3;
            // The fee_amount_target is not included here. We only use the fee_amount_target when computing the buy_token_missing_amount
            while buy_token_amount > buy_token_amount_received {
                assert(remaining_iterations != 0, 'Too many iterations');

                // Collect the necessary token from amount
                let buy_token_missing_amount = buy_token_amount + fee_amount_target - buy_token_amount_received;
                let (sell_token_buy_amount_transfer, overflows) = muldiv(
                    sell_token_last_amount_used, buy_token_missing_amount, buy_token_last_amount_received, true,
                );
                assert(overflows == false, 'Overflow: swap iteration');
                assert(sell_token_buy_amount_transfer <= remaining_sell_token_amount, 'Insufficient token from amount');
                self.collect_sell_token(contract_address, caller_address, sell_token, sell_token_buy_amount_transfer);

                // Swap
                self.apply_routes(routes.clone(), contract_address);

                sell_token_amount_used += sell_token_buy_amount_transfer;
                sell_token_last_amount_used = sell_token_buy_amount_transfer;
                remaining_sell_token_amount -= sell_token_buy_amount_transfer;
                remaining_iterations -= 1;
                let buy_token_balance = buy_token.balanceOf(contract_address);
                buy_token_last_amount_received = buy_token_balance - buy_token_amount_received;
                buy_token_amount_received = buy_token_balance;
            }

            (sell_token_amount_used, buy_token_amount_received)
        }

        fn assert_no_remaining_tokens(
            ref self: ContractState, contract_address: ContractAddress, mut routes: Span<Route>, mut checked_tokens: Felt252Dict<u64>,
        ) {
            if routes.len() == 0 {
                return;
            }

            // Retrieve current route
            let route: @Route = routes.pop_front().unwrap();

            // Transfer residual tokens
            self.assert_no_remaining_token(contract_address, *route.sell_token, ref checked_tokens);
            self.assert_no_remaining_token(contract_address, *route.buy_token, ref checked_tokens);

            self.assert_no_remaining_tokens(contract_address, routes, checked_tokens);
        }

        fn assert_no_remaining_token(
            ref self: ContractState, contract_address: ContractAddress, token_address: ContractAddress, ref checked_tokens: Felt252Dict<u64>,
        ) {
            // Only do the check when token balance has not already been checked
            if checked_tokens.get(token_address.into()) == 0 {
                // Check balance and transfer tokens if necessary
                let token = IERC20Dispatcher { contract_address: token_address };
                let token_balance = token.balanceOf(contract_address);
                assert(token_balance == 0, 'Residual tokens');
                checked_tokens.insert(token_address.into(), 1);
            }
        }

        fn apply_routes(ref self: ContractState, mut routes: Array<Route>, contract_address: ContractAddress) {
            if (routes.len() == 0) {
                return;
            }

            // Retrieve current route
            let route: Route = routes.pop_front().unwrap();
            match route.swap {
                RouteSwap::Direct(swap) => self.apply_direct_swap(contract_address, route.sell_token, route.buy_token, swap),
                RouteSwap::Branch(swap) => self.apply_branch_swap(contract_address, route.sell_token, route.buy_token, swap),
            }

            self.apply_routes(routes, contract_address);
        }

        fn apply_direct_swap(
            ref self: ContractState, contract_address: ContractAddress, sell_token: ContractAddress, buy_token: ContractAddress, swap: DirectSwap,
        ) {
            // Calculating tokens to be passed to the exchange
            // percentage should be 2 * 10**10 for 2%
            assert(swap.percent > 0, 'Invalid route percent');
            assert(swap.percent <= MAX_ROUTE_PERCENT, 'Invalid route percent');

            let sell_token_balance = IERC20Dispatcher { contract_address: sell_token }.balanceOf(contract_address);
            let (sell_token_amount, overflows) = muldiv(sell_token_balance, swap.percent.into(), MAX_ROUTE_PERCENT.into(), false);
            assert(overflows == false, 'Overflow: Invalid percent');

            // Call swap
            self
                .resolve_exchange_dispatcher(swap.exchange_address)
                .swap(swap.exchange_address, sell_token, sell_token_amount, buy_token, 0, contract_address, swap.additional_swap_params);
        }

        fn apply_branch_swap(
            ref self: ContractState, contract_address: ContractAddress, sell_token: ContractAddress, buy_token: ContractAddress, swap: BranchSwap,
        ) {
            assert(swap.principal.percent > 0, 'Invalid route percent');
            assert(swap.principal.percent <= MAX_ROUTE_PERCENT, 'Invalid route percent');

            let sell_token_balance = IERC20Dispatcher { contract_address: sell_token }.balanceOf(contract_address);
            let (sell_token_amount, overflow) = muldiv(sell_token_balance, swap.principal.percent.into(), MAX_ROUTE_PERCENT.into(), false);
            assert(overflow == false, 'Overflow: Invalid percent');
       
            // Compute the minimal price of execution for the alternative. We aim for 0.5% more than the principal price for the alternative to be executed.
            let principal_amount_out = self
                .resolve_exchange_dispatcher(swap.principal.exchange_address)
                .quote(swap.principal.exchange_address, sell_token, sell_token_amount, buy_token, contract_address, swap.principal.additional_swap_params.clone());

            let (principal_price, overflow) = muldiv(principal_amount_out, 18446744073709551616, sell_token_amount, true);
            assert(overflow == false, 'Overflow: Invalid price');

            let (minimum_price, overflow) = muldiv(principal_price, 1005, 100, false);
            assert(overflow == false, 'Overflow: Invalid price');

            // Execute branch swap
            let mut remaining_sell_token_amount = sell_token_amount;
            for alternative in swap.alternatives {
                remaining_sell_token_amount -= self.apply_alternative_swap(
                    contract_address,
                    sell_token,
                    remaining_sell_token_amount,
                    buy_token,
                    minimum_price,
                    alternative
                ).unwrap_or_default();
            };

            // Call principal swap
            self.resolve_exchange_dispatcher(swap.principal.exchange_address)
                .swap(
                    swap.principal.exchange_address,
                    sell_token,
                    remaining_sell_token_amount,
                    buy_token,
                    0,
                    contract_address,
                    swap.principal.additional_swap_params,
                );
        }

        fn apply_alternative_swap(
            ref self: ContractState,
            contract_address: ContractAddress,
            sell_token: ContractAddress,
            sell_token_amount: u256,
            buy_token: ContractAddress,
            minimum_price: u256,
            swap: AlternativeSwap,
        ) -> Option<u256> {
            assert(swap.percent > 0, 'Invalid route percent');
            assert(swap.percent <= MAX_ROUTE_PERCENT, 'Invalid route percent');

            // Try to match the minimum price set for the alternative swap to be effective. If the price constraint cannot
            // be fullfilled then return None
            let adjusted_amount_in = self
                .optimize_alternative_swap_amount_in(contract_address, sell_token, sell_token_amount, buy_token, minimum_price, swap.clone())?;

            self
                .resolve_exchange_dispatcher(swap.exchange_address)
                .swap(swap.exchange_address, sell_token, adjusted_amount_in, buy_token, 0, contract_address, swap.additional_swap_params);

            Option::Some(adjusted_amount_in)
        }

        fn optimize_alternative_swap_amount_in(
            ref self: ContractState,
            contract_address: ContractAddress,
            sell_token: ContractAddress,
            sell_token_amount: u256,
            buy_token: ContractAddress,
            minimum_price: u256,
            swap: AlternativeSwap,
        ) -> Option<u256> {
            let (mut sell_token_amount, overflows) = muldiv(sell_token_amount, swap.percent.into(), MAX_ROUTE_PERCENT.into(), false);
            if overflows {
                return Option::None;
            }

            let exchange = self.resolve_exchange_dispatcher(swap.exchange_address);

            let (mut iteration, mut amount_out) = (0_u8, Option::None);
            while iteration < 5 && amount_out.is_none()  {
                let buy_token_amount = exchange
                    .quote(swap.exchange_address, sell_token, sell_token_amount, buy_token, contract_address, swap.additional_swap_params.clone());

                // compute price, we use 64 bits precision so 2**64 == 18446744073709551616
                let (price, overflow) = muldiv(buy_token_amount, 18446744073709551616, sell_token_amount, true);
                if !overflow && price >= minimum_price {
                    amount_out = Option::Some(sell_token_amount);
                }

                // We reduce the amount in by 10% at each iteration, resulting in halving the amout in at iteration 5.
                let (new_sell_token_amount, _) = muldiv(sell_token_amount, 90, 100, false);

                sell_token_amount = if new_sell_token_amount == 0 { 1 } else { new_sell_token_amount };
                iteration += 1;
            };

            // Returns None if we didn't manage to match the price
            amount_out
        }

        fn resolve_exchange_dispatcher(self: @ContractState, exchange_address: ContractAddress) -> ISwapAdapterLibraryDispatcher {
            let adapter_class_hash = self.get_adapter_class_hash(exchange_address);
            assert(!adapter_class_hash.is_zero(), 'Unknown exchange');

            ISwapAdapterLibraryDispatcher { class_hash: adapter_class_hash }
        }

        fn compute_swap_exact_token_to_integrator_fee_amount(
            ref self: ContractState,
            sell_token_amount: u256,
            buy_token_amount: u256,
            integrator_fee_recipient: ContractAddress,
            integrator_fee_amount_bps: u128,
            fee_policy: FeePolicy,
        ) -> u256 {
            if integrator_fee_recipient.is_zero() || integrator_fee_amount_bps.is_zero() {
                0_u256
            } else if fee_policy == FeePolicy::FeeOnSell {
                // We need to compute what the integrator fee amount in buy token is equivalent in sell token (sell token amount already includes the
                // fee while the buy token amount does not)
                let (fee_amount, overflows) = muldiv(
                    sell_token_amount, integrator_fee_amount_bps.into(), (10000_u256 + integrator_fee_amount_bps.into()), false,
                );
                assert(overflows == false, 'Overflow: Integrator fee');
                fee_amount
            } else if fee_policy == FeePolicy::FeeOnBuy {
                self.fee.compute_fee_amount(buy_token_amount, integrator_fee_amount_bps)
            } else {
                0_u256
            }
        }
    }
}
