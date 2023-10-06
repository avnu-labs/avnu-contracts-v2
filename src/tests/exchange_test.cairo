use avnu::tests::helper::{deploy_exchange, deploy_mock_token, deploy_mock_fee_collector,};
use avnu::exchange::{Exchange, IExchangeDispatcher, IExchangeDispatcherTrait};
use avnu::exchange::Exchange::{Swap, Event, OwnershipTransferred};
use avnu::models::Route;
use array::ArrayTrait;
use starknet::{
    contract_address_to_felt252, ContractAddress, contract_address_const, class_hash_const
};
use starknet::testing::{set_contract_address, pop_log_raw};
use option::{Option, OptionTrait};

mod GetOwner {
    use super::{deploy_exchange, IExchangeDispatcherTrait, contract_address_const};

    #[test]
    #[available_gas(2000000)]
    fn should_return_owner() {
        // Given
        let exchange = deploy_exchange();
        let expected = contract_address_const::<0x1>();

        // When
        let result = exchange.get_owner();

        // Then
        assert(result == expected, 'invalid owner');
    }
}

mod TransferOwnership {
    use super::{
        deploy_exchange, IExchangeDispatcherTrait, contract_address_const, set_contract_address
    };

    #[test]
    #[available_gas(2000000)]
    fn should_change_owner() {
        // Given
        let exchange = deploy_exchange();
        let new_owner = contract_address_const::<0x3456>();
        set_contract_address(exchange.get_owner());

        // When
        let result = exchange.transfer_ownership(new_owner);

        // Then
        assert(result == true, 'invalid result');
        let owner = exchange.get_owner();
        assert(owner == new_owner, 'invalid owner');
    }

    #[test]
    #[available_gas(2000000)]
    #[should_panic(expected: ('Caller is not the owner', 'ENTRYPOINT_FAILED'))]
    fn should_fail_when_caller_is_not_the_owner() {
        // Given
        let exchange = deploy_exchange();
        let new_owner = contract_address_const::<0x3456>();
        set_contract_address(contract_address_const::<0x1234>());

        // When & Then
        exchange.transfer_ownership(new_owner);
    }

    #[test]
    #[available_gas(2000000)]
    #[should_panic(expected: ('New owner is the zero address', 'ENTRYPOINT_FAILED'))]
    fn should_fail_when_owner_is_0() {
        // Given
        let exchange = deploy_exchange();
        let new_owner = contract_address_const::<0x0>();
        set_contract_address(exchange.get_owner());

        // When & Then
        let result = exchange.transfer_ownership(new_owner);
    }
}

mod UpgradeClass {
    use super::{
        deploy_exchange, IExchangeDispatcherTrait, class_hash_const, set_contract_address,
        contract_address_const
    };

    #[test]
    #[available_gas(2000000)]
    fn should_upgrade_class() {
        // Given
        let exchange = deploy_exchange();
        let new_class = class_hash_const::<0x3456>();
        set_contract_address(exchange.get_owner());

        // When
        let result = exchange.upgrade_class(new_class);

        // Then
        assert(result == true, 'invalid result');
    }

    #[test]
    #[available_gas(2000000)]
    #[should_panic(expected: ('Caller is not the owner', 'ENTRYPOINT_FAILED'))]
    fn should_fail_when_caller_is_not_the_owner() {
        // Given
        let exchange = deploy_exchange();
        let new_class = class_hash_const::<0x3456>();
        set_contract_address(contract_address_const::<0x1234>());

        // When & Then
        exchange.upgrade_class(new_class);
    }
}

mod GetAdapterClassHash {
    use super::{
        deploy_exchange, IExchangeDispatcherTrait, contract_address_const, class_hash_const
    };

    #[test]
    #[available_gas(2000000)]
    fn should_return_adapter_class_hash() {
        // Given
        let exchange = deploy_exchange();
        let router_address = contract_address_const::<0x0>();
        let expected = class_hash_const::<0x0>();

        // When
        let result = exchange.get_adapter_class_hash(router_address);

        // Then
        assert(result == expected, 'invalid class hash');
    }
}

mod SetAdapterClassHash {
    use super::{
        deploy_exchange, IExchangeDispatcherTrait, contract_address_const, class_hash_const,
        set_contract_address
    };

    #[test]
    #[available_gas(2000000)]
    fn should_set_adapter_class() {
        // Given
        let exchange = deploy_exchange();
        let router_address = contract_address_const::<0x2>();
        let new_class_hash = class_hash_const::<0x1>();
        set_contract_address(exchange.get_owner());

        // When
        let result = exchange.set_adapter_class_hash(router_address, new_class_hash);

        // Then
        assert(result == true, 'invalid result');
        let class_hash = exchange.get_adapter_class_hash(router_address);
        assert(class_hash == new_class_hash, 'invalid class hash');
    }

    #[test]
    #[available_gas(2000000)]
    #[should_panic(expected: ('Caller is not the owner', 'ENTRYPOINT_FAILED'))]
    fn should_fail_when_caller_is_not_the_owner() {
        // Given
        let exchange = deploy_exchange();
        let router_address = contract_address_const::<0x2>();
        let new_class_hash = class_hash_const::<0x1>();
        set_contract_address(contract_address_const::<0x1234>());

        // When & Then
        exchange.set_adapter_class_hash(router_address, new_class_hash);
    }
}

mod GetFeeCollectorAddress {
    use super::{deploy_exchange, IExchangeDispatcherTrait, contract_address_const};

    #[test]
    #[available_gas(2000000)]
    fn should_return_fee_collector_address() {
        // Given
        let exchange = deploy_exchange();
        let expected = contract_address_const::<0x2>();

        // When
        let result = exchange.get_fee_collector_address();

        // Then
        assert(result == expected, 'invalid fee collector address');
    }
}

mod SetFeeCollectorAddress {
    use super::{
        deploy_exchange, IExchangeDispatcherTrait, contract_address_const, set_contract_address
    };

    #[test]
    #[available_gas(2000000)]
    fn should_set_fee_collector_address() {
        // Given
        let exchange = deploy_exchange();
        let new_address = contract_address_const::<0x123>();
        set_contract_address(exchange.get_owner());

        // When
        let result = exchange.set_fee_collector_address(new_address);

        // Then
        assert(result == true, 'invalid result');
        let fee_collector_address = exchange.get_fee_collector_address();
        assert(fee_collector_address == fee_collector_address, 'invalid fee collector address');
    }

    #[test]
    #[available_gas(2000000)]
    #[should_panic(expected: ('Caller is not the owner', 'ENTRYPOINT_FAILED'))]
    fn should_fail_when_caller_is_not_the_owner() {
        // Given
        let exchange = deploy_exchange();
        let new_address = contract_address_const::<0x123>();
        set_contract_address(contract_address_const::<0x1234>());

        // When & Then
        exchange.set_fee_collector_address(new_address);
    }
}

mod MultiRouteSwap {
    use avnu::tests::mocks::mock_erc20::MockERC20::Transfer;
    use super::{
        Exchange, IExchangeDispatcher, ContractAddress, deploy_exchange, deploy_mock_token,
        IExchangeDispatcherTrait, ArrayTrait, contract_address_const, Route, set_contract_address,
        pop_log_raw, Swap, OptionTrait, Event, OwnershipTransferred, deploy_mock_fee_collector,
        contract_address_to_felt252
    };

    struct SwapScenario {
        exchange: IExchangeDispatcher,
        token_from_address: ContractAddress,
        token_from_amount: u256,
        token_to_address: ContractAddress,
        token_to_amount: u256,
        token_to_min_amount: u256,
        beneficiary: ContractAddress,
        routes: Array<Route>,
        expected_event: Swap
    }

    #[test]
    #[available_gas(20000000)]
    fn should_call_swap() {
        // Given
        let exchange = deploy_exchange();
        let token_from_address = deploy_mock_token(10).contract_address;
        let token_to_address = deploy_mock_token(10).contract_address;
        let beneficiary = contract_address_const::<0x12345>();
        let token_from_amount = u256 { low: 10, high: 0 };
        let token_to_min_amount = u256 { low: 9, high: 0 };
        let token_to_amount = u256 { low: 9, high: 0 };
        let mut routes = ArrayTrait::new();
        routes
            .append(
                Route {
                    token_from: token_from_address,
                    token_to: token_to_address,
                    exchange_address: contract_address_const::<0x12>(),
                    percent: 100,
                    additional_swap_params: ArrayTrait::new()
                }
            );
        set_contract_address(beneficiary);

        // When
        let result = exchange
            .multi_route_swap(
                token_from_address,
                token_from_amount,
                token_to_address,
                token_to_amount,
                token_to_min_amount,
                beneficiary,
                0,
                contract_address_const::<0x0>(),
                routes
            );

        // Then
        assert(result == true, 'invalid result');
        let (mut keys, mut data) = pop_log_raw(exchange.contract_address).unwrap();
        let event: Swap = starknet::Event::deserialize(ref keys, ref data).unwrap();
        let expected_event = Swap {
            taker_address: beneficiary,
            sell_address: token_from_address,
            sell_amount: token_from_amount,
            buy_address: token_to_address,
            buy_amount: u256 { low: 10, high: 0 },
            beneficiary: beneficiary
        };
        assert(event == expected_event, 'invalid swap event');
        assert(pop_log_raw(exchange.contract_address).is_none(), 'no more events');

        // Verify no fees
        assert(pop_log_raw(token_from_address).is_none(), 'no more events');
    }

    #[test]
    #[available_gas(20000000)]
    #[should_panic(expected: ('Token from balance is too low', 'ENTRYPOINT_FAILED'))]
    fn should_throw_error_when_caller_balance_is_too_low() {
        // Given
        let exchange = deploy_exchange();
        let token_from_address = deploy_mock_token(8).contract_address;
        let token_to_address = deploy_mock_token(10).contract_address;
        let beneficiary = contract_address_const::<0x12345>();
        let token_from_amount = u256 { low: 10, high: 0 };
        let token_to_min_amount = u256 { low: 9, high: 0 };
        let token_to_amount = u256 { low: 9, high: 0 };
        let mut routes = ArrayTrait::new();
        routes
            .append(
                Route {
                    token_from: token_from_address,
                    token_to: token_to_address,
                    exchange_address: contract_address_const::<0x12>(),
                    percent: 100,
                    additional_swap_params: ArrayTrait::new()
                }
            );
        set_contract_address(beneficiary);

        // When & Then
        exchange
            .multi_route_swap(
                token_from_address,
                token_from_amount,
                token_to_address,
                token_to_amount,
                token_to_min_amount,
                beneficiary,
                0,
                contract_address_const::<0x0>(),
                routes
            );
    }

    #[test]
    #[available_gas(20000000)]
    fn should_call_swap_when_fees() {
        // Given
        let exchange = deploy_exchange();
        let fee_collector = deploy_mock_fee_collector(0x1, 0x1, 200).contract_address;
        let token_from_address = deploy_mock_token(100).contract_address;
        let token_to_address = deploy_mock_token(100).contract_address;
        let beneficiary = contract_address_const::<0x12345>();
        let token_from_amount = u256 { low: 100, high: 0 };
        let token_to_min_amount = u256 { low: 99, high: 0 };
        let token_to_amount = u256 { low: 99, high: 0 };
        let mut routes = ArrayTrait::new();
        routes
            .append(
                Route {
                    token_from: token_from_address,
                    token_to: token_to_address,
                    exchange_address: contract_address_const::<0x12>(),
                    percent: 100,
                    additional_swap_params: ArrayTrait::new()
                }
            );
        set_contract_address(exchange.get_owner());
        exchange.set_fee_collector_address(fee_collector);
        set_contract_address(beneficiary);

        // When
        let result = exchange
            .multi_route_swap(
                token_from_address,
                token_from_amount,
                token_to_address,
                token_to_amount,
                token_to_min_amount,
                beneficiary,
                0x64, // 1%, 100 bps
                contract_address_const::<0x111>(),
                routes
            );

        // Then
        assert(result == true, 'invalid result');
        let (mut keys, mut data) = pop_log_raw(exchange.contract_address).unwrap();
        let event: Swap = starknet::Event::deserialize(ref keys, ref data).unwrap();
        let expected_event = Swap {
            taker_address: beneficiary,
            sell_address: token_from_address,
            sell_amount: token_from_amount,
            buy_address: token_to_address,
            buy_amount: u256 { low: 100, high: 0 },
            beneficiary: beneficiary
        };
        assert(event == expected_event, 'invalid swap event');
        assert(pop_log_raw(exchange.contract_address).is_none(), 'no more events');

        // Verify transfers
        // Verify integrator's fees
        let (mut keys, mut data) = pop_log_raw(token_from_address).unwrap();
        let event: Transfer = starknet::Event::deserialize(ref keys, ref data).unwrap();
        let expected_event = Transfer { to: contract_address_const::<0x111>(), amount: 1_u256 };
        assert(event == expected_event, 'invalid token transfer');

        // Verify avnu's fees
        let (mut keys, mut data) = pop_log_raw(token_from_address).unwrap();
        let event: Transfer = starknet::Event::deserialize(ref keys, ref data).unwrap();
        let expected_event = Transfer { to: fee_collector, amount: 2_u256 };
        assert(event == expected_event, 'invalid token transfer');
        assert(pop_log_raw(token_from_address).is_none(), 'no more events');
    }

    #[test]
    #[available_gas(20000000)]
    fn should_call_swap_when_multiple_routes() {
        // Given
        let exchange = deploy_exchange();
        let token_1_address = deploy_mock_token(10).contract_address;
        let token_2_address = deploy_mock_token(10).contract_address;
        let token_3_address = deploy_mock_token(10).contract_address;
        let token_4_address = deploy_mock_token(10).contract_address;
        let token_5_address = deploy_mock_token(10).contract_address;
        let beneficiary = contract_address_const::<0x12345>();
        let token_from_amount = u256 { low: 10, high: 0 };
        let token_to_min_amount = u256 { low: 9, high: 0 };
        let token_to_amount = u256 { low: 9, high: 0 };
        let mut routes = ArrayTrait::new();
        let exchange_address = contract_address_const::<0x12>();
        routes
            .append(
                Route {
                    token_from: token_1_address,
                    token_to: token_2_address,
                    exchange_address,
                    percent: 100,
                    additional_swap_params: ArrayTrait::new(),
                }
            );
        routes
            .append(
                Route {
                    token_from: token_2_address,
                    token_to: token_2_address,
                    exchange_address,
                    percent: 33,
                    additional_swap_params: ArrayTrait::new(),
                }
            );
        routes
            .append(
                Route {
                    token_from: token_2_address,
                    token_to: token_3_address,
                    exchange_address,
                    percent: 50,
                    additional_swap_params: ArrayTrait::new(),
                }
            );
        routes
            .append(
                Route {
                    token_from: token_2_address,
                    token_to: token_4_address,
                    exchange_address,
                    percent: 100,
                    additional_swap_params: ArrayTrait::new(),
                }
            );
        routes
            .append(
                Route {
                    token_from: token_3_address,
                    token_to: token_5_address,
                    exchange_address,
                    percent: 100,
                    additional_swap_params: ArrayTrait::new(),
                }
            );
        routes
            .append(
                Route {
                    token_from: token_4_address,
                    token_to: token_5_address,
                    exchange_address,
                    percent: 100,
                    additional_swap_params: ArrayTrait::new(),
                }
            );
        set_contract_address(beneficiary);

        // When
        let result = exchange
            .multi_route_swap(
                token_1_address,
                token_from_amount,
                token_5_address,
                token_to_amount,
                token_to_min_amount,
                beneficiary,
                0,
                contract_address_const::<0x0>(),
                routes
            );

        // Then
        assert(result == true, 'invalid result');
        let (mut keys, mut data) = pop_log_raw(exchange.contract_address).unwrap();
        let event: avnu::exchange::Exchange::Swap = starknet::Event::deserialize(ref keys, ref data)
            .unwrap();
        let expected_event = Swap {
            taker_address: beneficiary,
            sell_address: token_1_address,
            sell_amount: token_from_amount,
            buy_address: token_5_address,
            buy_amount: u256 { low: 10, high: 0 },
            beneficiary: beneficiary
        };
        assert(event == expected_event, 'invalid swap event');
        assert(pop_log_raw(exchange.contract_address).is_none(), 'no more events');

        // Verify no fees
        assert(pop_log_raw(token_1_address).is_none(), 'no more events');
    }

    #[test]
    #[available_gas(20000000)]
    #[should_panic(expected: ('Unknown exchange', 'ENTRYPOINT_FAILED'))]
    fn should_fail_when_exchange_is_unknown() {
        // Given
        let exchange = deploy_exchange();
        let token_from_address = deploy_mock_token(10).contract_address;
        let token_to_address = deploy_mock_token(10).contract_address;
        let beneficiary = contract_address_const::<0x12345>();
        let token_from_amount = u256 { low: 10, high: 0 };
        let token_to_min_amount = u256 { low: 9, high: 0 };
        let token_to_amount = u256 { low: 9, high: 0 };
        let mut routes = ArrayTrait::new();
        routes
            .append(
                Route {
                    token_from: token_from_address,
                    token_to: token_to_address,
                    exchange_address: contract_address_const::<0x10>(),
                    percent: 100,
                    additional_swap_params: ArrayTrait::new()
                }
            );
        set_contract_address(beneficiary);

        // When & Then
        let result = exchange
            .multi_route_swap(
                token_from_address,
                token_from_amount,
                token_to_address,
                token_to_amount,
                token_to_min_amount,
                beneficiary,
                0,
                contract_address_const::<0x0>(),
                routes
            );
    }

    #[test]
    #[available_gas(20000000)]
    #[should_panic(expected: ('Insufficient tokens received', 'ENTRYPOINT_FAILED'))]
    fn should_fail_when_insufficient_tokens_received() {
        // Given
        let exchange = deploy_exchange();
        let token_from_address = deploy_mock_token(10).contract_address;
        let token_to_address = deploy_mock_token(2).contract_address;
        let beneficiary = contract_address_const::<0x12345>();
        let token_from_amount = u256 { low: 10, high: 0 };
        let token_to_min_amount = u256 { low: 9, high: 0 };
        let token_to_amount = u256 { low: 9, high: 0 };
        let mut routes = ArrayTrait::new();
        routes
            .append(
                Route {
                    token_from: token_from_address,
                    token_to: token_to_address,
                    exchange_address: contract_address_const::<0x12>(),
                    percent: 100,
                    additional_swap_params: ArrayTrait::new()
                }
            );
        set_contract_address(beneficiary);

        // When & Then
        let result = exchange
            .multi_route_swap(
                token_from_address,
                token_from_amount,
                token_to_address,
                token_to_amount,
                token_to_min_amount,
                beneficiary,
                0,
                contract_address_const::<0x0>(),
                routes
            );
    }

    #[test]
    #[available_gas(20000000)]
    #[should_panic(expected: ('Beneficiary is not the caller', 'ENTRYPOINT_FAILED'))]
    fn should_fail_when_beneficiary_is_not_the_caller() {
        // Given
        let exchange = deploy_exchange();
        let beneficiary = contract_address_const::<0x12345>();
        let token_from_address = contract_address_const::<0x1>();
        let token_from_amount = u256 { low: 10, high: 0 };
        let token_to_address = contract_address_const::<0x2>();
        let token_to_min_amount = u256 { low: 9, high: 0 };
        let token_to_amount = u256 { low: 9, high: 0 };
        let mut routes = ArrayTrait::new();
        routes
            .append(
                Route {
                    token_from: token_from_address,
                    token_to: token_to_address,
                    exchange_address: contract_address_const::<0x12>(),
                    percent: 100,
                    additional_swap_params: ArrayTrait::new()
                }
            );

        // When & Then
        exchange
            .multi_route_swap(
                token_from_address,
                token_from_amount,
                token_to_address,
                token_to_amount,
                token_to_min_amount,
                beneficiary,
                0,
                contract_address_const::<0x0>(),
                routes
            );
    }
}
