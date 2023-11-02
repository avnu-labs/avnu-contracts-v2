use avnu::tests::helper::{deploy_exchange, deploy_mock_token};
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

mod GetFeesActive {
    use super::{deploy_exchange, IExchangeDispatcherTrait};

    #[test]
    #[available_gas(2000000)]
    fn should_return_a_bool() {
        // Given
        let exchange = deploy_exchange();

        // When
        let result = exchange.get_fees_active();

        // Then
        assert(result == false, 'invalid fees_active');
    }
}

mod SetFeesActive {
    use super::{
        deploy_exchange, IExchangeDispatcherTrait, contract_address_const, set_contract_address
    };

    #[test]
    #[available_gas(2000000)]
    fn should_set_fees_active() {
        // Given
        let exchange = deploy_exchange();
        set_contract_address(exchange.get_owner());

        // When
        let result = exchange.set_fees_active(true);

        // Then
        assert(result == true, 'invalid set_fees_active result');
        let fees_active = exchange.get_fees_active();
        assert(fees_active == true, 'invalid fees_active');
    }

    #[test]
    #[available_gas(2000000)]
    #[should_panic(expected: ('Caller is not the owner', 'ENTRYPOINT_FAILED'))]
    fn should_fail_when_caller_is_not_the_owner() {
        // Given
        let exchange = deploy_exchange();
        set_contract_address(contract_address_const::<0x1234>());

        // When & Then
        exchange.set_fees_active(true);
    }
}

mod GetFeesRecipient {
    use super::{deploy_exchange, IExchangeDispatcherTrait, contract_address_const};

    #[test]
    #[available_gas(2000000)]
    fn should_return_recipient() {
        // Given
        let exchange = deploy_exchange();
        let expected = contract_address_const::<0x2>();

        // When
        let result = exchange.get_fees_recipient();

        // Then
        assert(result == expected, 'invalid fees_recipient');
    }
}

mod SetFeesRecipient {
    use super::{
        deploy_exchange, IExchangeDispatcherTrait, contract_address_const, set_contract_address
    };

    #[test]
    #[available_gas(2000000)]
    fn should_set_fees_recipient() {
        // Given
        let exchange = deploy_exchange();
        let recipient = contract_address_const::<0x1234>();
        set_contract_address(exchange.get_owner());

        // When
        let result = exchange.set_fees_recipient(recipient);

        // Then
        assert(result == true, 'invalid recipient result');
        let fees_recipient = exchange.get_fees_recipient();
        assert(fees_recipient == recipient, 'invalid fees_recipient');
    }

    #[test]
    #[available_gas(2000000)]
    #[should_panic(expected: ('Caller is not the owner', 'ENTRYPOINT_FAILED'))]
    fn should_fail_when_caller_is_not_the_owner() {
        // Given
        let exchange = deploy_exchange();
        let recipient = contract_address_const::<0x1234>();
        set_contract_address(contract_address_const::<0x1234>());

        // When & Then
        exchange.set_fees_recipient(recipient);
    }
}

mod GetFeesBps0 {
    use super::{deploy_exchange, IExchangeDispatcherTrait};

    #[test]
    #[available_gas(2000000)]
    fn should_return_bps() {
        // Given
        let exchange = deploy_exchange();

        // When
        let result = exchange.get_fees_bps_0();

        // Then
        assert(result == 0, 'invalid fees_bps');
    }
}

mod SetFeesBps0 {
    use super::{
        deploy_exchange, IExchangeDispatcherTrait, contract_address_const, set_contract_address
    };

    #[test]
    #[available_gas(2000000)]
    fn should_set_fees_bps_0() {
        // Given
        let exchange = deploy_exchange();
        set_contract_address(exchange.get_owner());

        // When
        let result = exchange.set_fees_bps_0(10);

        // Then
        assert(result == true, 'invalid bps result');
        let fees_bps = exchange.get_fees_bps_0();
        assert(fees_bps == 10, 'invalid fees_bps');
    }

    #[test]
    #[available_gas(2000000)]
    #[should_panic(expected: ('Fees are too high', 'ENTRYPOINT_FAILED'))]
    fn should_fail_when_fees_are_too_high() {
        // Given
        let exchange = deploy_exchange();
        set_contract_address(exchange.get_owner());

        // When & Then
        exchange.set_fees_bps_0(500);
    }

    #[test]
    #[available_gas(2000000)]
    #[should_panic(expected: ('Caller is not the owner', 'ENTRYPOINT_FAILED'))]
    fn should_fail_when_caller_is_not_the_owner() {
        // Given
        let exchange = deploy_exchange();
        set_contract_address(contract_address_const::<0x1234>());

        // When & Then
        exchange.set_fees_bps_0(10);
    }
}

mod GetFeesBps1 {
    use super::{deploy_exchange, IExchangeDispatcherTrait};

    #[test]
    #[available_gas(2000000)]
    fn should_return_bps() {
        // Given
        let exchange = deploy_exchange();

        // When
        let result = exchange.get_fees_bps_1();

        // Then
        assert(result == 0, 'invalid fees_bps');
    }
}

mod SetFeesBps1 {
    use super::{
        deploy_exchange, IExchangeDispatcherTrait, contract_address_const, set_contract_address,
    };

    #[test]
    #[available_gas(2000000)]
    fn should_set_fees_bps_1() {
        // Given
        let exchange = deploy_exchange();
        set_contract_address(exchange.get_owner());

        // When
        let result = exchange.set_fees_bps_1(10);

        // Then
        assert(result == true, 'invalid bps result');
        let fees_bps = exchange.get_fees_bps_1();
        assert(fees_bps == 10, 'invalid fees_bps');
    }

    #[test]
    #[available_gas(2000000)]
    #[should_panic(expected: ('Fees are too high', 'ENTRYPOINT_FAILED'))]
    fn should_fail_when_fees_are_too_high() {
        // Given
        let exchange = deploy_exchange();
        set_contract_address(exchange.get_owner());

        // When & Then
        exchange.set_fees_bps_1(500);
    }

    #[test]
    #[available_gas(2000000)]
    #[should_panic(expected: ('Caller is not the owner', 'ENTRYPOINT_FAILED'))]
    fn should_fail_when_caller_is_not_the_owner() {
        // Given
        let exchange = deploy_exchange();
        set_contract_address(contract_address_const::<0x1234>());

        // When & Then
        exchange.set_fees_bps_1(10);
    }
}

mod MultiRouteSwap {
    use avnu::tests::mocks::mock_erc20::MockERC20::Transfer;
    use avnu::interfaces::erc20::{IERC20Dispatcher, IERC20DispatcherTrait};
    use super::{
        Exchange, IExchangeDispatcher, ContractAddress, deploy_exchange, deploy_mock_token,
        IExchangeDispatcherTrait, ArrayTrait, contract_address_const, Route, set_contract_address,
        pop_log_raw, Swap, OptionTrait, Event, OwnershipTransferred, contract_address_to_felt252
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
        let beneficiary = contract_address_const::<0x12345>();
        let token_from = deploy_mock_token(beneficiary, 10);
        let token_from_address = token_from.contract_address;
        let token_to = deploy_mock_token(beneficiary, 0);
        let token_to_address = token_to.contract_address;
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
        token_from.approve(exchange.contract_address, token_from_amount);

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

        // Verify that beneficiary receives tokens to
        let balance = token_to.balanceOf(beneficiary);
        assert(balance == 10_u256, 'Invalid beneficiary balance');
        let (mut keys, mut data) = pop_log_raw(token_to_address).unwrap();
        let event: Transfer = starknet::Event::deserialize(ref keys, ref data).unwrap();
        let expected_event = Transfer { to: beneficiary, amount: 10_u256 };
        assert(event == expected_event, 'Invalid beneficiary balance');
        assert(pop_log_raw(token_to_address).is_none(), 'no more token_to events');
        assert(pop_log_raw(token_from_address).is_none(), 'no more token_from events');
    }

    #[test]
    #[available_gas(20000000)]
    #[should_panic(expected: ('Residual tokens', 'ENTRYPOINT_FAILED'))]
    fn should_throw_error_when_residual_tokens() {
        // Given
        let exchange = deploy_exchange();
        let beneficiary = contract_address_const::<0x12345>();
        let token_from = deploy_mock_token(beneficiary, 10);
        let token_from_address = token_from.contract_address;
        let token_to = deploy_mock_token(beneficiary, 0);
        let token_to_address = token_to.contract_address;
        let token_from_amount = u256 { low: 10, high: 0 };
        let token_to_min_amount = u256 { low: 1, high: 0 };
        let token_to_amount = u256 { low: 1, high: 0 };
        let mut routes = ArrayTrait::new();
        routes
            .append(
                Route {
                    token_from: token_from_address,
                    token_to: token_to_address,
                    exchange_address: contract_address_const::<0x12>(),
                    percent: 40,
                    additional_swap_params: ArrayTrait::new()
                }
            );
        set_contract_address(beneficiary);
        token_from.approve(exchange.contract_address, token_from_amount);

        // When
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
    #[should_panic(expected: ('Token from amount is 0', 'ENTRYPOINT_FAILED'))]
    fn should_throw_error_when_token_from_amount_is_0() {
        // Given
        let exchange = deploy_exchange();
        let beneficiary = contract_address_const::<0x12345>();
        let token_from = deploy_mock_token(beneficiary, 10);
        let token_from_address = token_from.contract_address;
        let token_to = deploy_mock_token(beneficiary, 0);
        let token_to_address = token_to.contract_address;
        let token_from_amount = u256 { low: 0, high: 0 };
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
        token_from.approve(exchange.contract_address, token_from_amount);

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
    #[should_panic(expected: ('Token from balance is too low', 'ENTRYPOINT_FAILED'))]
    fn should_throw_error_when_caller_balance_is_too_low() {
        // Given
        let exchange = deploy_exchange();
        let beneficiary = contract_address_const::<0x12345>();
        let token_from = deploy_mock_token(beneficiary, 5);
        let token_from_address = token_from.contract_address;
        let token_to = deploy_mock_token(beneficiary, 0);
        let token_to_address = token_to.contract_address;
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
        token_from.approve(exchange.contract_address, token_from_amount);

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
        let beneficiary = contract_address_const::<0x12345>();
        set_contract_address(exchange.get_owner());
        let fees_recipient = contract_address_const::<0x1111>();
        exchange.set_fees_recipient(fees_recipient);
        exchange.set_fees_active(true);
        exchange.set_fees_bps_0(20);
        exchange.set_fees_bps_1(40);
        let token_from = deploy_mock_token(beneficiary, 1000);
        let token_from_address = token_from.contract_address;
        let token_to = deploy_mock_token(beneficiary, 0);
        let token_to_address = token_to.contract_address;
        let token_from_amount = u256 { low: 1000, high: 0 };
        let token_to_min_amount = u256 { low: 950, high: 0 };
        let token_to_amount = u256 { low: 950, high: 0 };
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
        token_from.approve(exchange.contract_address, token_from_amount);

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
            buy_amount: u256 { low: 988, high: 0 },
            beneficiary: beneficiary
        };
        assert(event == expected_event, 'invalid swap event');
        assert(pop_log_raw(exchange.contract_address).is_none(), 'no more contract events');

        // Verify transfers
        // Verify integrator's fees
        let (mut keys, mut data) = pop_log_raw(token_to_address).unwrap();
        let event: Transfer = starknet::Event::deserialize(ref keys, ref data).unwrap();
        let expected_event = Transfer { to: contract_address_const::<0x111>(), amount: 10_u256 };
        assert(event == expected_event, 'invalid token transfer');

        // Verify avnu's fees
        let (mut keys, mut data) = pop_log_raw(token_to_address).unwrap();
        let event: Transfer = starknet::Event::deserialize(ref keys, ref data).unwrap();
        let expected_event = Transfer { to: fees_recipient, amount: 2_u256 };
        assert(event == expected_event, 'invalid token transfer');

        // Verify that beneficiary receives tokens to
        let balance = token_to.balanceOf(beneficiary);
        assert(balance == 988_u256, 'Invalid beneficiary balance');
        let (mut keys, mut data) = pop_log_raw(token_to_address).unwrap();
        let event: Transfer = starknet::Event::deserialize(ref keys, ref data).unwrap();
        let expected_event = Transfer { to: beneficiary, amount: 988_u256 };
        assert(event == expected_event, 'Invalid beneficiary balance');
        assert(pop_log_raw(token_to_address).is_none(), 'no more token_to events');
        assert(pop_log_raw(token_from_address).is_none(), 'no more token_from events');
    }

    #[test]
    #[should_panic(expected: ('Integrator fees are too high', 'ENTRYPOINT_FAILED'))]
    #[available_gas(20000000)]
    fn should_throw_error_when_integrator_fees_are_too_high() {
        // Given
        let exchange = deploy_exchange();
        let beneficiary = contract_address_const::<0x12345>();
        set_contract_address(exchange.get_owner());
        let fees_recipient = contract_address_const::<0x1111>();
        let token_from = deploy_mock_token(beneficiary, 1000);
        let token_from_address = token_from.contract_address;
        let token_to = deploy_mock_token(beneficiary, 0);
        let token_to_address = token_to.contract_address;
        let token_from_amount = u256 { low: 1000, high: 0 };
        let token_to_min_amount = u256 { low: 950, high: 0 };
        let token_to_amount = u256 { low: 950, high: 0 };
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
        token_from.approve(exchange.contract_address, token_from_amount);

        // When & Then
        let result = exchange
            .multi_route_swap(
                token_from_address,
                token_from_amount,
                token_to_address,
                token_to_amount,
                token_to_min_amount,
                beneficiary,
                600,
                contract_address_const::<0x111>(),
                routes
            );
    }

    #[test]
    #[available_gas(20000000)]
    fn should_call_swap_when_fees_and_multiple_routes() {
        // Given
        let exchange = deploy_exchange();
        let beneficiary = contract_address_const::<0x12345>();
        set_contract_address(exchange.get_owner());
        let fees_recipient = contract_address_const::<0x1111>();
        exchange.set_fees_recipient(fees_recipient);
        exchange.set_fees_active(true);
        exchange.set_fees_bps_0(20);
        exchange.set_fees_bps_1(40);
        let token_from = deploy_mock_token(beneficiary, 1000);
        let token_from_address = token_from.contract_address;
        let token_to = deploy_mock_token(beneficiary, 0);
        let token_to_address = token_to.contract_address;
        let token_from_amount = u256 { low: 1000, high: 0 };
        let token_to_min_amount = u256 { low: 950, high: 0 };
        let token_to_amount = u256 { low: 950, high: 0 };
        let mut routes = ArrayTrait::new();
        routes
            .append(
                Route {
                    token_from: token_from_address,
                    token_to: token_to_address,
                    exchange_address: contract_address_const::<0x12>(),
                    percent: 60,
                    additional_swap_params: ArrayTrait::new()
                }
            );
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
        token_from.approve(exchange.contract_address, token_from_amount);

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
            buy_amount: u256 { low: 986, high: 0 },
            beneficiary: beneficiary
        };

        assert(event == expected_event, 'invalid swap event');
        assert(pop_log_raw(exchange.contract_address).is_none(), 'no more contract events');

        // Verify transfers
        // Verify integrator's fees
        let (mut keys, mut data) = pop_log_raw(token_to_address).unwrap();
        let event: Transfer = starknet::Event::deserialize(ref keys, ref data).unwrap();
        let expected_event = Transfer { to: contract_address_const::<0x111>(), amount: 10_u256 };
        assert(event == expected_event, 'invalid token transfer');

        // Verify avnu's fees
        let (mut keys, mut data) = pop_log_raw(token_to_address).unwrap();
        let event: Transfer = starknet::Event::deserialize(ref keys, ref data).unwrap();
        let expected_event = Transfer { to: fees_recipient, amount: 4_u256 };
        assert(event == expected_event, 'invalid token transfer');

        // Verify that beneficiary receives tokens to
        let balance = token_to.balanceOf(beneficiary);
        assert(balance == 986_u256, 'Invalid beneficiary balance');
        let (mut keys, mut data) = pop_log_raw(token_to_address).unwrap();
        let event: Transfer = starknet::Event::deserialize(ref keys, ref data).unwrap();
        let expected_event = Transfer { to: beneficiary, amount: 986_u256 };
        assert(event == expected_event, 'Invalid beneficiary balance');
        assert(pop_log_raw(token_to_address).is_none(), 'no more token_to events');
        assert(pop_log_raw(token_from_address).is_none(), 'no more token_from events');
    }

    #[test]
    #[available_gas(20000000)]
    fn should_call_swap_when_multiple_routes() {
        // Given
        let exchange = deploy_exchange();
        let beneficiary = contract_address_const::<0x12345>();
        let token_1 = deploy_mock_token(beneficiary, 10);
        let token_1_address = token_1.contract_address;
        let token_2_address = deploy_mock_token(beneficiary, 0).contract_address;
        let token_3_address = deploy_mock_token(beneficiary, 0).contract_address;
        let token_4_address = deploy_mock_token(beneficiary, 0).contract_address;
        let token_5 = deploy_mock_token(beneficiary, 0);
        let token_5_address = token_5.contract_address;
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
        token_1.approve(exchange.contract_address, token_from_amount);

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
        assert(pop_log_raw(exchange.contract_address).is_none(), 'no more contract events');

        // Verify that beneficiary receives tokens to
        let balance = token_5.balanceOf(beneficiary);
        assert(balance == 10_u256, 'Invalid beneficiary balance');
        let (mut keys, mut data) = pop_log_raw(token_5_address).unwrap();
        let event: Transfer = starknet::Event::deserialize(ref keys, ref data).unwrap();
        let expected_event = Transfer { to: beneficiary, amount: 10_u256 };
        assert(event == expected_event, 'Invalid beneficiary balance');
        assert(pop_log_raw(token_1_address).is_none(), 'no more token_1 events');
        assert(pop_log_raw(token_2_address).is_none(), 'no more token_2 events');
        assert(pop_log_raw(token_3_address).is_none(), 'no more token_3 events');
        assert(pop_log_raw(token_4_address).is_none(), 'no more token_4 events');
        assert(pop_log_raw(token_5_address).is_none(), 'no more token_5 events');
    }

    #[test]
    #[should_panic(expected: ('Routes is empty', 'ENTRYPOINT_FAILED'))]
    #[available_gas(20000000)]
    fn should_throw_error_when_routes_is_empty() {
        // Given
        let exchange = deploy_exchange();
        let beneficiary = contract_address_const::<0x12345>();
        let token_from = deploy_mock_token(beneficiary, 10);
        let token_from_address = token_from.contract_address;
        let token_to = deploy_mock_token(beneficiary, 0);
        let token_to_address = token_to.contract_address;
        let token_from_amount = u256 { low: 10, high: 0 };
        let token_to_min_amount = u256 { low: 9, high: 0 };
        let token_to_amount = u256 { low: 9, high: 0 };
        let mut routes = ArrayTrait::new();
        set_contract_address(beneficiary);
        token_from.approve(exchange.contract_address, token_from_amount);

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
    #[should_panic(expected: ('Invalid route percent', 'ENTRYPOINT_FAILED'))]
    fn should_throw_error_when_route_percent_is_higher_than_100() {
        // Given
        let exchange = deploy_exchange();
        let beneficiary = contract_address_const::<0x12345>();
        let token_from = deploy_mock_token(beneficiary, 10);
        let token_from_address = token_from.contract_address;
        let token_to = deploy_mock_token(beneficiary, 0);
        let token_to_address = token_to.contract_address;
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
                    percent: 101,
                    additional_swap_params: ArrayTrait::new()
                }
            );
        set_contract_address(beneficiary);
        token_from.approve(exchange.contract_address, token_from_amount);

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
    #[should_panic(expected: ('Invalid route percent', 'ENTRYPOINT_FAILED'))]
    fn should_throw_error_when_route_percent_is_higher_is_0() {
        // Given
        let exchange = deploy_exchange();
        let beneficiary = contract_address_const::<0x12345>();
        let token_from = deploy_mock_token(beneficiary, 10);
        let token_from_address = token_from.contract_address;
        let token_to = deploy_mock_token(beneficiary, 0);
        let token_to_address = token_to.contract_address;
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
                    percent: 0,
                    additional_swap_params: ArrayTrait::new()
                }
            );
        set_contract_address(beneficiary);
        token_from.approve(exchange.contract_address, token_from_amount);

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
    #[should_panic(expected: ('Invalid token from', 'ENTRYPOINT_FAILED'))]
    #[available_gas(20000000)]
    fn should_throw_error_when_first_token_from_is_not_token_from() {
        // Given
        let exchange = deploy_exchange();
        let beneficiary = contract_address_const::<0x12345>();
        let token_from = deploy_mock_token(beneficiary, 10);
        let token_from_address = token_from.contract_address;
        let token_from_address_2 = deploy_mock_token(beneficiary, 10).contract_address;
        let token_to = deploy_mock_token(beneficiary, 0);
        let token_to_address = token_to.contract_address;
        let token_from_amount = u256 { low: 10, high: 0 };
        let token_to_min_amount = u256 { low: 9, high: 0 };
        let token_to_amount = u256 { low: 9, high: 0 };
        let mut routes = ArrayTrait::new();
        routes
            .append(
                Route {
                    token_from: token_from_address_2,
                    token_to: token_to_address,
                    exchange_address: contract_address_const::<0x12>(),
                    percent: 100,
                    additional_swap_params: ArrayTrait::new()
                }
            );
        set_contract_address(beneficiary);
        token_from.approve(exchange.contract_address, token_from_amount);

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
    #[should_panic(expected: ('Invalid token to', 'ENTRYPOINT_FAILED'))]
    fn should_throw_error_when_last_token_to_is_not_token_to() {
        // Given
        let exchange = deploy_exchange();
        let beneficiary = contract_address_const::<0x12345>();
        let token_1 = deploy_mock_token(beneficiary, 10);
        let token_1_address = token_1.contract_address;
        let token_2_address = deploy_mock_token(beneficiary, 0).contract_address;
        let token_3_address = deploy_mock_token(beneficiary, 0).contract_address;
        let token_4_address = deploy_mock_token(beneficiary, 0).contract_address;
        let token_5_address = deploy_mock_token(beneficiary, 0).contract_address;
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
                    token_to: token_3_address,
                    exchange_address,
                    percent: 100,
                    additional_swap_params: ArrayTrait::new(),
                }
            );
        set_contract_address(beneficiary);
        token_1.approve(exchange.contract_address, token_from_amount);

        // When & Then
        exchange
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
    }

    #[test]
    #[available_gas(20000000)]
    #[should_panic(expected: ('Unknown exchange', 'ENTRYPOINT_FAILED'))]
    fn should_fail_when_exchange_is_unknown() {
        // Given
        let exchange = deploy_exchange();
        let beneficiary = contract_address_const::<0x12345>();
        let token_from = deploy_mock_token(beneficiary, 10);
        let token_from_address = token_from.contract_address;
        let token_to = deploy_mock_token(beneficiary, 0);
        let token_to_address = token_to.contract_address;
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
        token_from.approve(exchange.contract_address, token_from_amount);

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
        let beneficiary = contract_address_const::<0x12345>();
        let token_from = deploy_mock_token(beneficiary, 10);
        let token_from_address = token_from.contract_address;
        let token_to = deploy_mock_token(beneficiary, 0);
        let token_to_address = token_to.contract_address;
        let token_from_amount = u256 { low: 10, high: 0 };
        let token_to_min_amount = u256 { low: 11, high: 0 };
        let token_to_amount = u256 { low: 11, high: 0 };
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
        token_from.approve(exchange.contract_address, token_from_amount);

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
        let token_from = deploy_mock_token(beneficiary, 10);
        let token_from_address = token_from.contract_address;
        let token_to = deploy_mock_token(beneficiary, 0);
        let token_to_address = token_to.contract_address;
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
