use avnu::models::Route;
use starknet::{ClassHash, ContractAddress};

#[starknet::interface]
pub trait IOldExchange<TContractState> {
    fn get_owner(self: @TContractState) -> ContractAddress;
    fn transfer_ownership(ref self: TContractState, new_owner: ContractAddress) -> bool;
    fn upgrade_class(ref self: TContractState, new_class_hash: ClassHash) -> bool;
    fn get_adapter_class_hash(self: @TContractState, exchange_address: ContractAddress) -> ClassHash;
    fn set_adapter_class_hash(ref self: TContractState, exchange_address: ContractAddress, adapter_class_hash: ClassHash) -> bool;
    fn get_fees_active(self: @TContractState) -> bool;
    fn set_fees_active(ref self: TContractState, active: bool) -> bool;
    fn get_fees_recipient(self: @TContractState) -> ContractAddress;
    fn set_fees_recipient(ref self: TContractState, recipient: ContractAddress) -> bool;
    fn get_fees_bps_0(self: @TContractState) -> u128;
    fn set_fees_bps_0(ref self: TContractState, bps: u128) -> bool;
    fn get_fees_bps_1(self: @TContractState) -> u128;
    fn set_fees_bps_1(ref self: TContractState, bps: u128) -> bool;
    fn get_swap_exact_token_to_fees_bps(self: @TContractState) -> u128;
    fn set_swap_exact_token_to_fees_bps(ref self: TContractState, bps: u128) -> bool;
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
        routes: Array<Route>,
    ) -> bool;
}

#[starknet::contract]
pub mod OldExchange {
    use avnu::adapters::{ISwapAdapterDispatcherTrait, ISwapAdapterLibraryDispatcher};
    use avnu::interfaces::locker::{ILocker, ISwapAfterLockDispatcherTrait, ISwapAfterLockLibraryDispatcher};
    use avnu::models::Route;
    use avnu_lib::interfaces::erc20::{IERC20Dispatcher, IERC20DispatcherTrait};
    use avnu_lib::math::muldiv::muldiv;
    use core::dict::Felt252Dict;
    use core::num::traits::Zero;
    use core::starknet::syscalls::replace_class_syscall;
    use starknet::storage::{StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess, StoragePointerWriteAccess};
    use starknet::{ClassHash, ContractAddress, SyscallResultTrait, get_caller_address, get_contract_address};
    use super::IOldExchange;

    // 100 * 10 ** 10 => (10 decimals)
    const MAX_ROUTE_PERCENT: u128 = 1000000000000;
    const MAX_AVNU_FEES_BPS: u128 = 100;
    const MAX_INTEGRATOR_FEES_BPS: u128 = 500;

    #[storage]
    struct Storage {
        Ownable_owner: ContractAddress,
        #[feature("deprecated_legacy_map")]
        AdapterClassHash: LegacyMap<ContractAddress, ClassHash>,
        fees_active: bool,
        fees_bps_0: u128,
        fees_bps_1: u128,
        swap_exact_token_to_fees_bps: u128,
        fees_recipient: ContractAddress,
    }

    #[event]
    #[derive(starknet::Event, Drop, PartialEq)]
    pub enum Event {
        Swap: Swap,
        OwnershipTransferred: OwnershipTransferred,
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

    #[derive(starknet::Event, Drop, PartialEq)]
    pub struct OwnershipTransferred {
        previous_owner: ContractAddress,
        new_owner: ContractAddress,
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
    fn constructor(ref self: ContractState, owner: ContractAddress, fee_recipient: ContractAddress) {
        // Set owner & fee collector address
        self._transfer_ownership(owner);
        self.fees_recipient.write(fee_recipient)
    }

    #[abi(embed_v0)]
    impl OldExchange of IOldExchange<ContractState> {
        fn get_owner(self: @ContractState) -> ContractAddress {
            self.Ownable_owner.read()
        }

        fn transfer_ownership(ref self: ContractState, new_owner: ContractAddress) -> bool {
            self.assert_only_owner();
            assert(!new_owner.is_zero(), 'New owner is the zero address');
            self._transfer_ownership(new_owner);
            true
        }

        fn upgrade_class(ref self: ContractState, new_class_hash: ClassHash) -> bool {
            self.assert_only_owner();
            replace_class_syscall(new_class_hash).unwrap_syscall();
            true
        }

        fn get_adapter_class_hash(self: @ContractState, exchange_address: ContractAddress) -> ClassHash {
            self.AdapterClassHash.read(exchange_address)
        }

        fn set_adapter_class_hash(ref self: ContractState, exchange_address: ContractAddress, adapter_class_hash: ClassHash) -> bool {
            self.assert_only_owner();
            self.AdapterClassHash.write(exchange_address, adapter_class_hash);
            true
        }

        fn get_fees_active(self: @ContractState) -> bool {
            self.fees_active.read()
        }

        fn set_fees_active(ref self: ContractState, active: bool) -> bool {
            self.assert_only_owner();
            self.fees_active.write(active);
            true
        }

        fn get_fees_recipient(self: @ContractState) -> ContractAddress {
            self.fees_recipient.read()
        }

        fn set_fees_recipient(ref self: ContractState, recipient: ContractAddress) -> bool {
            self.assert_only_owner();
            self.fees_recipient.write(recipient);
            true
        }

        fn get_fees_bps_0(self: @ContractState) -> u128 {
            self.fees_bps_0.read()
        }

        fn set_fees_bps_0(ref self: ContractState, bps: u128) -> bool {
            self.assert_only_owner();
            assert(bps <= MAX_AVNU_FEES_BPS, 'Fees are too high');
            self.fees_bps_0.write(bps);
            true
        }

        fn get_fees_bps_1(self: @ContractState) -> u128 {
            self.fees_bps_1.read()
        }

        fn set_fees_bps_1(ref self: ContractState, bps: u128) -> bool {
            self.assert_only_owner();
            assert(bps <= MAX_AVNU_FEES_BPS, 'Fees are too high');
            self.fees_bps_1.write(bps);
            true
        }

        fn get_swap_exact_token_to_fees_bps(self: @ContractState) -> u128 {
            self.swap_exact_token_to_fees_bps.read()
        }

        fn set_swap_exact_token_to_fees_bps(ref self: ContractState, bps: u128) -> bool {
            self.assert_only_owner();
            assert(bps <= MAX_AVNU_FEES_BPS, 'Fees are too high');
            self.swap_exact_token_to_fees_bps.write(bps);
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

            // Swap
            self.apply_routes(routes, contract_address);

            // Execute all the post-swap actions (verify min amount, collect fees, transfer tokens, emit event...)
            self
                .after_swap(
                    contract_address,
                    caller_address,
                    sell_token,
                    sell_token_amount,
                    buy_token,
                    buy_token_min_amount,
                    beneficiary,
                    integrator_fee_amount_bps,
                    integrator_fee_recipient,
                    routes_span.len(),
                );

            // Dict of bools are supported yet
            let mut checked_tokens: Felt252Dict<u64> = Default::default();
            // Token to has already been checked
            checked_tokens.insert(buy_token_address.into(), 1);
            self.assert_no_remaining_tokens(contract_address, routes_span, checked_tokens);
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

            // Swap
            let (sell_token_amount_used, buy_token_amount_received) = self
                ._swap_exact_token_to(
                    contract_address, caller_address, sell_token, sell_token_amount, sell_token_max_amount, buy_token, buy_token_amount, routes,
                );

            // Check amount of token to and transfer tokens
            assert(buy_token_amount <= buy_token_amount_received, 'Insufficient tokens received');
            buy_token.transfer(beneficiary, buy_token_amount);

            // Collect fees
            let fees_amount = buy_token_amount_received - buy_token_amount;
            if (fees_amount > 0) {
                assert(self.get_fees_active(), 'Fees are not active');
                let fees_recipient = self.get_fees_recipient();
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
    }

    #[generate_trait]
    impl Internal of InternalTrait {
        fn assert_only_owner(self: @ContractState) {
            let owner = self.get_owner();
            let caller = get_caller_address();
            assert(!caller.is_zero(), 'Caller is the zero address');
            assert(caller == owner, 'Caller is not the owner');
        }

        fn _transfer_ownership(ref self: ContractState, new_owner: ContractAddress) {
            let previous_owner = self.get_owner();
            self.Ownable_owner.write(new_owner);
            self.emit(OwnershipTransferred { previous_owner, new_owner });
        }

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

        fn after_swap(
            ref self: ContractState,
            contract_address: ContractAddress,
            caller_address: ContractAddress,
            sell_token: IERC20Dispatcher,
            sell_token_amount: u256,
            buy_token: IERC20Dispatcher,
            buy_token_min_amount: u256,
            beneficiary: ContractAddress,
            integrator_fee_amount_bps: u128,
            integrator_fee_recipient: ContractAddress,
            route_len: usize,
        ) {
            // Collect fees
            let buy_token_amount_received = buy_token.balanceOf(contract_address);
            let buy_token_final_amount = self
                .collect_fees(buy_token, buy_token_amount_received, integrator_fee_amount_bps, integrator_fee_recipient, route_len);

            // Check amount of token to and transfer tokens
            assert(buy_token_min_amount <= buy_token_final_amount, 'Insufficient tokens received');
            buy_token.transfer(beneficiary, buy_token_final_amount);

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

            let target_fees_bps = self.get_swap_exact_token_to_fees_bps();
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
            };

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

            // Calculating tokens to be passed to the exchange
            // percentage should be 2 * 10**10 for 2%
            assert(route.percent > 0, 'Invalid route percent');
            assert(route.percent <= MAX_ROUTE_PERCENT, 'Invalid route percent');
            let sell_token_balance = IERC20Dispatcher { contract_address: route.sell_token }.balanceOf(contract_address);
            let (sell_token_amount, overflows) = muldiv(sell_token_balance, route.percent.into(), MAX_ROUTE_PERCENT.into(), false);
            assert(overflows == false, 'Overflow: Invalid percent');

            // Get adapter class hash
            let adapter_class_hash = self.get_adapter_class_hash(route.exchange_address);
            assert(!adapter_class_hash.is_zero(), 'Unknown exchange');

            // Call swap
            ISwapAdapterLibraryDispatcher { class_hash: adapter_class_hash }
                .swap(
                    route.exchange_address, route.sell_token, sell_token_amount, route.buy_token, 0, contract_address, route.additional_swap_params,
                );

            self.apply_routes(routes, contract_address);
        }

        fn collect_fees(
            ref self: ContractState,
            token: IERC20Dispatcher,
            amount: u256,
            integrator_fee_amount_bps: u128,
            integrator_fee_recipient: ContractAddress,
            route_len: usize,
        ) -> u256 {
            // Collect integrator's fees
            assert(integrator_fee_amount_bps <= MAX_INTEGRATOR_FEES_BPS, 'Integrator fees are too high');
            let integrator_fees_collected = self.collect_fee_bps(token, amount, integrator_fee_amount_bps, integrator_fee_recipient, true);

            // Collect AVNU's fees
            let bps = if route_len > 1 {
                self.get_fees_bps_1()
            } else {
                self.get_fees_bps_0()
            };
            let avnu_fees_collected = self.collect_fee_bps(token, amount, bps, self.get_fees_recipient(), self.get_fees_active());

            // Compute and return amount minus fees
            amount - integrator_fees_collected - avnu_fees_collected
        }

        fn collect_fee_bps(
            ref self: ContractState, token: IERC20Dispatcher, amount: u256, fee_amount_bps: u128, fee_recipient: ContractAddress, is_active: bool,
        ) -> u256 {
            // Fee collector is active when recipient & amount are defined, don't throw exception for UX purpose
            // -> It's integrator work to defined it correctly
            if (!fee_amount_bps.is_zero() && !fee_recipient.is_zero() && is_active) {
                // Compute fee amount
                let (fee_amount, overflows) = muldiv(amount, fee_amount_bps.into(), 10000_u256, false);
                assert(overflows == false, 'Overflow: Invalid fee');

                // Collect fees from contract
                token.transfer(fee_recipient, fee_amount);

                fee_amount
            } else {
                0
            }
        }
    }
}
