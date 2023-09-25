use starknet::{ContractAddress, ClassHash};
use avnu::models::Route;

#[starknet::interface]
trait IExchange<TContractState> {
    fn get_owner(self: @TContractState) -> ContractAddress;
    fn transfer_ownership(ref self: TContractState, new_owner: ContractAddress) -> bool;
    fn upgrade_class(ref self: TContractState, new_class_hash: ClassHash) -> bool;
    fn get_adapter_class_hash(
        self: @TContractState, exchange_address: ContractAddress
    ) -> ClassHash;
    fn set_adapter_class_hash(
        ref self: TContractState, exchange_address: ContractAddress, adapter_class_hash: ClassHash
    ) -> bool;
    fn get_fee_collector_address(self: @TContractState) -> ContractAddress;
    fn set_fee_collector_address(
        ref self: TContractState, new_fee_collector_address: ContractAddress
    ) -> bool;
    fn multi_route_swap(
        ref self: TContractState,
        token_from_address: ContractAddress,
        token_from_amount: u256,
        token_to_address: ContractAddress,
        token_to_amount: u256,
        token_to_min_amount: u256,
        beneficiary: ContractAddress,
        integrator_fee_amount_bps: u128,
        integrator_fee_recipient: ContractAddress,
        routes: Array<Route>,
    ) -> bool;
}

#[starknet::contract]
mod Exchange {
    use array::ArrayTrait;
    use option::OptionTrait;
    use result::ResultTrait;
    use traits::{TryInto, Into};
    use zeroable::Zeroable;
    use super::IExchange;
    use starknet::{
        replace_class_syscall, ContractAddress, ClassHash, get_caller_address, get_contract_address
    };
    use avnu::adapters::{ISwapAdapterLibraryDispatcher, ISwapAdapterDispatcherTrait};
    use avnu::interfaces::erc20::{IERC20Dispatcher, IERC20DispatcherTrait};
    use avnu::interfaces::locker::{
        ILocker, ISwapAfterLockLibraryDispatcher, ISwapAfterLockDispatcherTrait
    };
    use avnu::interfaces::fee_collector::{IFeeCollectorDispatcher, IFeeCollectorDispatcherTrait};
    use avnu::math::muldiv::muldiv;
    use avnu::models::Route;

    #[storage]
    struct Storage {
        Ownable_owner: ContractAddress,
        AdapterClassHash: LegacyMap<ContractAddress, ClassHash>,
        FeeCollectorAddress: ContractAddress,
    }

    #[event]
    #[derive(starknet::Event, Drop, PartialEq)]
    enum Event {
        Swap: Swap,
        OwnershipTransferred: OwnershipTransferred,
    }

    #[derive(Drop, starknet::Event, PartialEq)]
    struct Swap {
        taker_address: ContractAddress,
        sell_address: ContractAddress,
        sell_amount: u256,
        buy_address: ContractAddress,
        buy_amount: u256,
        beneficiary: ContractAddress,
    }

    #[derive(starknet::Event, Drop, PartialEq)]
    struct OwnershipTransferred {
        previous_owner: ContractAddress,
        new_owner: ContractAddress,
    }

    #[external(v0)]
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
        ref self: ContractState, owner: ContractAddress, fee_collector_address: ContractAddress
    ) {
        // Set owner & fee collector address
        self._transfer_ownership(owner);
        self.FeeCollectorAddress.write(fee_collector_address)
    }

    #[external(v0)]
    impl Exchange of IExchange<ContractState> {
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
            replace_class_syscall(new_class_hash);
            true
        }

        fn get_adapter_class_hash(
            self: @ContractState, exchange_address: ContractAddress
        ) -> ClassHash {
            self.AdapterClassHash.read(exchange_address)
        }

        fn set_adapter_class_hash(
            ref self: ContractState,
            exchange_address: ContractAddress,
            adapter_class_hash: ClassHash
        ) -> bool {
            self.assert_only_owner();
            self.AdapterClassHash.write(exchange_address, adapter_class_hash);
            true
        }

        fn get_fee_collector_address(self: @ContractState) -> ContractAddress {
            self.FeeCollectorAddress.read()
        }

        fn set_fee_collector_address(
            ref self: ContractState, new_fee_collector_address: ContractAddress
        ) -> bool {
            self.assert_only_owner();
            self.FeeCollectorAddress.write(new_fee_collector_address);
            true
        }

        fn multi_route_swap(
            ref self: ContractState,
            token_from_address: ContractAddress,
            token_from_amount: u256,
            token_to_address: ContractAddress,
            token_to_amount: u256,
            token_to_min_amount: u256,
            beneficiary: ContractAddress,
            integrator_fee_amount_bps: u128,
            integrator_fee_recipient: ContractAddress,
            routes: Array<Route>,
        ) -> bool {
            let caller_address = get_caller_address();
            let contract_address = get_contract_address();

            // In the future, the beneficiary may not be the caller
            // Check if beneficiary == caller_address
            assert(beneficiary == caller_address, 'Beneficiary is not the caller');

            // TODO: Maybe use transfer then swap instead of approve then swap, it would remove this transferFrom
            // Transfer tokens to contract
            IERC20Dispatcher { contract_address: token_from_address }
                .transferFrom(caller_address, contract_address, token_from_amount);

            // Collect fees
            self
                .collect_fees(
                    token_from_amount,
                    token_from_address,
                    integrator_fee_amount_bps,
                    integrator_fee_recipient
                );

            // Swap
            self.apply_routes(routes, contract_address);

            // Retrieve amount of token to received and transfer tokens
            let token_to = IERC20Dispatcher { contract_address: token_to_address };
            let received_token_to = token_to.balanceOf(contract_address);
            assert(token_to_min_amount <= received_token_to, 'Insufficient tokens received');
            token_to.transfer(beneficiary, received_token_to);

            // Emit event
            self
                .emit(
                    Swap {
                        taker_address: caller_address,
                        sell_address: token_from_address,
                        sell_amount: token_from_amount,
                        buy_address: token_to_address,
                        buy_amount: received_token_to,
                        beneficiary: beneficiary
                    }
                );

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

        fn apply_routes(
            ref self: ContractState, mut routes: Array<Route>, contract_address: ContractAddress
        ) {
            if (routes.len() == 0) {
                return;
            }

            // Retrieve current route
            let route: Route = routes.pop_front().unwrap();

            // Calculating tokens to be passed to the exchange
            // percentage should be 2 for 2%
            let token_from_balance = IERC20Dispatcher { contract_address: route.token_from }
                .balanceOf(contract_address);
            let (token_from_amount, overflows) = muldiv(
                token_from_balance, route.percent.into(), 100_u256, false
            );
            assert(overflows == false, 'Overflow: Invalid percent');

            // Get adapter class hash
            let adapter_class_hash = self.get_adapter_class_hash(route.exchange_address);
            assert(!adapter_class_hash.is_zero(), 'Unknown exchange');

            // Call swap
            ISwapAdapterLibraryDispatcher { class_hash: adapter_class_hash }
                .swap(
                    route.exchange_address,
                    route.token_from,
                    token_from_amount,
                    route.token_to,
                    0,
                    contract_address,
                    route.additional_swap_params,
                );

            self.apply_routes(routes, contract_address);
        }

        fn collect_fees(
            ref self: ContractState,
            amount: u256,
            token_address: ContractAddress,
            integrator_fee_amount_bps: u128,
            integrator_fee_recipient: ContractAddress,
        ) -> u256 {
            // Collect integrator's fees
            let integrator_fees_collected = self
                .collect_fee_bps(
                    amount, token_address, integrator_fee_amount_bps, integrator_fee_recipient, true
                );

            // Collect AVNU's fees
            let fee_collector_address = self.get_fee_collector_address();
            let fee_info = IFeeCollectorDispatcher { contract_address: fee_collector_address }
                .feeInfo();
            let avnu_fees_collected = self
                .collect_fee_bps(
                    amount,
                    token_address,
                    fee_info.fee_amount,
                    fee_collector_address,
                    fee_info.is_active
                );

            // Compute and return amount minus fees
            amount - integrator_fees_collected - avnu_fees_collected
        }

        fn collect_fee_bps(
            ref self: ContractState,
            amount: u256,
            token_address: ContractAddress,
            fee_amount_bps: u128,
            fee_recipient: ContractAddress,
            is_active: bool
        ) -> u256 {
            // Fee collector is active when recipient & amount are defined, don't throw exception for UX purpose
            // -> It's integrator work to defined it correctly
            if (!fee_amount_bps.is_zero() && !fee_recipient.is_zero() && is_active) {
                // Compute fee amount
                let (fee_amount, overflows) = muldiv(
                    amount, fee_amount_bps.into(), 10000_u256, false
                );
                assert(overflows == false, 'Overflow: Invalid fee');

                // Collect fees from contract
                IERC20Dispatcher { contract_address: token_address }
                    .transfer(fee_recipient, fee_amount);

                fee_amount
            } else {
                0
            }
        }
    }
}
