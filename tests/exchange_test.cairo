use avnu::components::fee::{IFeeDispatcher, IFeeDispatcherTrait, TokenFeeConfig};
use avnu::exchange::Exchange;
use avnu::exchange::Exchange::Swap;
use avnu::exchange::{IExchangeDispatcher, IExchangeDispatcherTrait};
use avnu::models::Route;
use avnu_lib::components::ownable::{IOwnableDispatcher, IOwnableDispatcherTrait};
use avnu_lib::interfaces::erc20::IERC20DispatcherTrait;
use starknet::class_hash::class_hash_const;
use starknet::testing::{pop_log_raw, set_contract_address};
use starknet::{ContractAddress, contract_address_const};
use super::helper::{deploy_exchange, deploy_mock_token, deploy_old_exchange};
const ROUTE_PERCENT_FACTOR: u128 = 10000000000;
use super::mocks::mock_erc20::MockERC20::Transfer;
use super::mocks::old_exchange::{IOldExchangeDispatcherTrait};
mod GetAdapterClassHash {
    use super::{IExchangeDispatcherTrait, class_hash_const, contract_address_const, deploy_exchange};

    #[test]
    fn should_return_adapter_class_hash() {
        // Given
        let (exchange, _, _) = deploy_exchange();
        let router_address = contract_address_const::<0x0>();
        let expected = class_hash_const::<0x0>();

        // When
        let result = exchange.get_adapter_class_hash(router_address);

        // Then
        assert(result == expected, 'invalid class hash');
    }
}

mod SetAdapterClassHash {
    use super::{IExchangeDispatcherTrait, IOwnableDispatcherTrait, class_hash_const, contract_address_const, deploy_exchange, set_contract_address};

    #[test]
    fn should_set_adapter_class() {
        // Given
        let (exchange, ownable, _) = deploy_exchange();
        let router_address = contract_address_const::<0x2>();
        let new_class_hash = class_hash_const::<0x1>();
        set_contract_address(ownable.get_owner());

        // When
        let result = exchange.set_adapter_class_hash(router_address, new_class_hash);

        // Then
        assert(result == true, 'invalid result');
        let class_hash = exchange.get_adapter_class_hash(router_address);
        assert(class_hash == new_class_hash, 'invalid class hash');
    }

    #[test]
    #[should_panic(expected: ('Caller is not the owner', 'ENTRYPOINT_FAILED'))]
    fn should_fail_when_caller_is_not_the_owner() {
        // Given
        let (exchange, _, _) = deploy_exchange();
        let router_address = contract_address_const::<0x2>();
        let new_class_hash = class_hash_const::<0x1>();
        set_contract_address(contract_address_const::<0x1234>());

        // When & Then
        exchange.set_adapter_class_hash(router_address, new_class_hash);
    }
}

mod MultiRouteSwap {
    use super::{
        ContractAddress, IERC20DispatcherTrait, IExchangeDispatcher, IExchangeDispatcherTrait, IFeeDispatcherTrait, IOwnableDispatcherTrait,
        ROUTE_PERCENT_FACTOR, Route, Swap, TokenFeeConfig, Transfer, contract_address_const, deploy_exchange, deploy_mock_token, pop_log_raw,
        set_contract_address,
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
        expected_event: Swap,
    }

    #[test]
    #[available_gas(20000000)]
    fn should_call_swap() {
        // Given
        let (exchange, _, _) = deploy_exchange();
        let beneficiary = contract_address_const::<0x12345>();
        let token_from = deploy_mock_token(beneficiary, 10, 1);
        let token_from_address = token_from.contract_address;
        let token_to = deploy_mock_token(beneficiary, 0, 2);
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
                    percent: 100 * ROUTE_PERCENT_FACTOR,
                    additional_swap_params: ArrayTrait::new(),
                },
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
                routes,
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
            beneficiary: beneficiary,
        };
        assert(event == expected_event, 'invalid swap event');
        assert(pop_log_raw(exchange.contract_address).is_none(), 'no more events');

        // Verify that beneficiary receives tokens to
        let balance = token_to.balanceOf(beneficiary);
        assert(balance == 10_u256, 'Invalid beneficiary balance');
        let (mut keys, mut data) = pop_log_raw(token_to_address).unwrap();
        let event: Transfer = starknet::Event::deserialize(ref keys, ref data).unwrap();
        let expected_event = Transfer { to: beneficiary, amount: 10_u256 };
        assert(event == expected_event, 'Invalid transfer event');
        assert(pop_log_raw(token_to_address).is_none(), 'no more token_to events');
        assert(pop_log_raw(token_from_address).is_none(), 'no more token_from events');
    }

    #[test]
    #[available_gas(20000000)]
    #[should_panic(expected: ('Residual tokens', 'ENTRYPOINT_FAILED'))]
    fn should_throw_error_when_residual_tokens() {
        // Given
        let (exchange, _, _) = deploy_exchange();
        let beneficiary = contract_address_const::<0x12345>();
        let token_from = deploy_mock_token(beneficiary, 10, 1);
        let token_from_address = token_from.contract_address;
        let token_to = deploy_mock_token(beneficiary, 0, 2);
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
                    percent: 40 * ROUTE_PERCENT_FACTOR,
                    additional_swap_params: ArrayTrait::new(),
                },
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
                routes,
            );
    }

    #[test]
    #[available_gas(20000000)]
    #[should_panic(expected: ('Token from amount is 0', 'ENTRYPOINT_FAILED'))]
    fn should_throw_error_when_token_from_amount_is_0() {
        // Given
        let (exchange, _, _) = deploy_exchange();
        let beneficiary = contract_address_const::<0x12345>();
        let token_from = deploy_mock_token(beneficiary, 10, 1);
        let token_from_address = token_from.contract_address;
        let token_to = deploy_mock_token(beneficiary, 0, 2);
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
                    percent: 100 * ROUTE_PERCENT_FACTOR,
                    additional_swap_params: ArrayTrait::new(),
                },
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
                routes,
            );
    }

    #[test]
    #[available_gas(20000000)]
    #[should_panic(expected: ('Token from balance is too low', 'ENTRYPOINT_FAILED'))]
    fn should_throw_error_when_caller_balance_is_too_low() {
        // Given
        let (exchange, _, _) = deploy_exchange();
        let beneficiary = contract_address_const::<0x12345>();
        let token_from = deploy_mock_token(beneficiary, 5, 1);
        let token_from_address = token_from.contract_address;
        let token_to = deploy_mock_token(beneficiary, 0, 2);
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
                    percent: 100 * ROUTE_PERCENT_FACTOR,
                    additional_swap_params: ArrayTrait::new(),
                },
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
                routes,
            );
    }

    #[test]
    #[available_gas(20000000)]
    fn should_call_swap_when_fees() {
        // Given
        let (exchange, ownable, fee) = deploy_exchange();
        let beneficiary = contract_address_const::<0x12345>();
        set_contract_address(ownable.get_owner());
        let fees_recipient = contract_address_const::<0x1111>();
        fee.set_fees_recipient(fees_recipient);
        fee.set_fees_bps_0(20);
        let token_from = deploy_mock_token(beneficiary, 1000, 1);
        let token_from_address = token_from.contract_address;
        let token_to = deploy_mock_token(beneficiary, 0, 2);
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
                    percent: 100 * ROUTE_PERCENT_FACTOR,
                    additional_swap_params: ArrayTrait::new(),
                },
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
                routes,
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
            beneficiary: beneficiary,
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
    #[available_gas(20000000)]
    fn should_call_swap_when_fees_and_integrator_is_whitelisted() {
        // Given
        let (exchange, ownable, fee) = deploy_exchange();
        let beneficiary = contract_address_const::<0x12345>();
        set_contract_address(ownable.get_owner());
        let fees_recipient = contract_address_const::<0x1111>();
        let integrator = contract_address_const::<'INTEGRATOR'>();
        fee.set_fees_recipient(fees_recipient);
        fee.set_fees_bps_0(20);
        fee.set_whitelisted_integrator(integrator, true);
        let token_from = deploy_mock_token(beneficiary, 1000, 1);
        let token_from_address = token_from.contract_address;
        let token_to = deploy_mock_token(beneficiary, 0, 2);
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
                    percent: 100 * ROUTE_PERCENT_FACTOR,
                    additional_swap_params: ArrayTrait::new(),
                },
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
                integrator,
                routes,
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
            buy_amount: u256 { low: 990, high: 0 },
            beneficiary: beneficiary,
        };
        assert(event == expected_event, 'invalid swap event');
        assert(pop_log_raw(exchange.contract_address).is_none(), 'no more contract events');

        // Verify transfers
        // Verify integrator's fees
        let (mut keys, mut data) = pop_log_raw(token_to_address).unwrap();
        let event: Transfer = starknet::Event::deserialize(ref keys, ref data).unwrap();
        let expected_event = Transfer { to: integrator, amount: 10_u256 };
        assert(event == expected_event, 'invalid token transfer');

        // Verify that beneficiary receives tokens to
        let balance = token_to.balanceOf(beneficiary);
        assert(balance == 990_u256, 'Invalid beneficiary balance');
        let (mut keys, mut data) = pop_log_raw(token_to_address).unwrap();
        let event: Transfer = starknet::Event::deserialize(ref keys, ref data).unwrap();
        let expected_event = Transfer { to: beneficiary, amount: 990_u256 };
        assert(event == expected_event, 'Invalid beneficiary balance');
        assert(pop_log_raw(token_to_address).is_none(), 'no more token_to events');
        assert(pop_log_raw(token_from_address).is_none(), 'no more token_from events');
    }

    #[test]
    #[should_panic(expected: ('Integrator fees are too high', 'ENTRYPOINT_FAILED'))]
    #[available_gas(20000000)]
    fn should_throw_error_when_integrator_fees_are_too_high() {
        // Given
        let (exchange, ownable, _) = deploy_exchange();
        let beneficiary = contract_address_const::<0x12345>();
        set_contract_address(ownable.get_owner());
        let token_from = deploy_mock_token(beneficiary, 1000, 1);
        let token_from_address = token_from.contract_address;
        let token_to = deploy_mock_token(beneficiary, 0, 2);
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
                    percent: 100 * ROUTE_PERCENT_FACTOR,
                    additional_swap_params: ArrayTrait::new(),
                },
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
                600,
                contract_address_const::<0x111>(),
                routes,
            );
    }

    #[test]
    #[available_gas(20000000)]
    fn should_call_swap_when_fees_and_multiple_routes() {
        // Given
        let (exchange, ownable, fee) = deploy_exchange();
        let beneficiary = contract_address_const::<0x12345>();
        set_contract_address(ownable.get_owner());
        let fees_recipient = contract_address_const::<0x1111>();
        fee.set_fees_recipient(fees_recipient);
        fee.set_fees_bps_1(20);
        fee.set_fees_bps_0(10);
        let token_from = deploy_mock_token(beneficiary, 1000, 1);
        let token_from_address = token_from.contract_address;
        let token_to = deploy_mock_token(beneficiary, 0, 2);
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
                    percent: 60 * ROUTE_PERCENT_FACTOR,
                    additional_swap_params: ArrayTrait::new(),
                },
            );
        routes
            .append(
                Route {
                    token_from: token_from_address,
                    token_to: token_to_address,
                    exchange_address: contract_address_const::<0x12>(),
                    percent: 100 * ROUTE_PERCENT_FACTOR,
                    additional_swap_params: ArrayTrait::new(),
                },
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
                routes,
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
            beneficiary: beneficiary,
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
    #[available_gas(20000000)]
    fn should_call_swap_when_multiple_routes() {
        // Given
        let (exchange, _, _) = deploy_exchange();
        let beneficiary = contract_address_const::<0x12345>();
        let token_1 = deploy_mock_token(beneficiary, 10, 1);
        let token_1_address = token_1.contract_address;
        let token_2_address = deploy_mock_token(beneficiary, 0, 2).contract_address;
        let token_3_address = deploy_mock_token(beneficiary, 0, 3).contract_address;
        let token_4_address = deploy_mock_token(beneficiary, 0, 4).contract_address;
        let token_5 = deploy_mock_token(beneficiary, 0, 5);
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
                    percent: 100 * ROUTE_PERCENT_FACTOR,
                    additional_swap_params: ArrayTrait::new(),
                },
            );
        routes
            .append(
                Route {
                    token_from: token_2_address,
                    token_to: token_2_address,
                    exchange_address,
                    percent: 33 * ROUTE_PERCENT_FACTOR,
                    additional_swap_params: ArrayTrait::new(),
                },
            );
        routes
            .append(
                Route {
                    token_from: token_2_address,
                    token_to: token_3_address,
                    exchange_address,
                    percent: 50 * ROUTE_PERCENT_FACTOR,
                    additional_swap_params: ArrayTrait::new(),
                },
            );
        routes
            .append(
                Route {
                    token_from: token_2_address,
                    token_to: token_4_address,
                    exchange_address,
                    percent: 100 * ROUTE_PERCENT_FACTOR,
                    additional_swap_params: ArrayTrait::new(),
                },
            );
        routes
            .append(
                Route {
                    token_from: token_3_address,
                    token_to: token_5_address,
                    exchange_address,
                    percent: 100 * ROUTE_PERCENT_FACTOR,
                    additional_swap_params: ArrayTrait::new(),
                },
            );
        routes
            .append(
                Route {
                    token_from: token_4_address,
                    token_to: token_5_address,
                    exchange_address,
                    percent: 100 * ROUTE_PERCENT_FACTOR,
                    additional_swap_params: ArrayTrait::new(),
                },
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
                routes,
            );

        // Then
        assert(result == true, 'invalid result');
        let (mut keys, mut data) = pop_log_raw(exchange.contract_address).unwrap();
        let event: avnu::exchange::Exchange::Swap = starknet::Event::deserialize(ref keys, ref data).unwrap();
        let expected_event = Swap {
            taker_address: beneficiary,
            sell_address: token_1_address,
            sell_amount: token_from_amount,
            buy_address: token_5_address,
            buy_amount: u256 { low: 10, high: 0 },
            beneficiary: beneficiary,
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
        let (exchange, _, _) = deploy_exchange();
        let beneficiary = contract_address_const::<0x12345>();
        let token_from = deploy_mock_token(beneficiary, 10, 1);
        let token_from_address = token_from.contract_address;
        let token_to = deploy_mock_token(beneficiary, 0, 2);
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
                routes,
            );
    }

    #[test]
    #[available_gas(20000000)]
    #[should_panic(expected: ('Invalid route percent', 'ENTRYPOINT_FAILED'))]
    fn should_throw_error_when_route_percent_is_higher_than_100() {
        // Given
        let (exchange, _, _) = deploy_exchange();
        let beneficiary = contract_address_const::<0x12345>();
        let token_from = deploy_mock_token(beneficiary, 10, 1);
        let token_from_address = token_from.contract_address;
        let token_to = deploy_mock_token(beneficiary, 0, 2);
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
                    percent: 101 * ROUTE_PERCENT_FACTOR,
                    additional_swap_params: ArrayTrait::new(),
                },
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
                routes,
            );
    }

    #[test]
    #[available_gas(20000000)]
    #[should_panic(expected: ('Invalid route percent', 'ENTRYPOINT_FAILED'))]
    fn should_throw_error_when_route_percent_is_higher_is_0() {
        // Given
        let (exchange, _, _) = deploy_exchange();
        let beneficiary = contract_address_const::<0x12345>();
        let token_from = deploy_mock_token(beneficiary, 10, 1);
        let token_from_address = token_from.contract_address;
        let token_to = deploy_mock_token(beneficiary, 0, 2);
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
                    percent: 0 * ROUTE_PERCENT_FACTOR,
                    additional_swap_params: ArrayTrait::new(),
                },
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
                routes,
            );
    }

    #[test]
    #[should_panic(expected: ('Invalid token from', 'ENTRYPOINT_FAILED'))]
    #[available_gas(20000000)]
    fn should_throw_error_when_first_token_from_is_not_token_from() {
        // Given
        let (exchange, _, _) = deploy_exchange();
        let beneficiary = contract_address_const::<0x12345>();
        let token_from = deploy_mock_token(beneficiary, 10, 1);

        let token_from_address = token_from.contract_address;
        let token_from_address_2 = deploy_mock_token(beneficiary, 10, 2).contract_address;
        let token_to = deploy_mock_token(beneficiary, 0, 2);
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
                    percent: 100 * ROUTE_PERCENT_FACTOR,
                    additional_swap_params: ArrayTrait::new(),
                },
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
                routes,
            );
    }

    #[test]
    #[available_gas(20000000)]
    #[should_panic(expected: ('Invalid token to', 'ENTRYPOINT_FAILED'))]
    fn should_throw_error_when_last_token_to_is_not_token_to() {
        // Given
        let (exchange, _, _) = deploy_exchange();
        let beneficiary = contract_address_const::<0x12345>();
        let token_1 = deploy_mock_token(beneficiary, 10, 1);
        let token_1_address = token_1.contract_address;
        let token_2_address = deploy_mock_token(beneficiary, 0, 2).contract_address;
        let token_3_address = deploy_mock_token(beneficiary, 0, 3).contract_address;
        let token_4_address = deploy_mock_token(beneficiary, 0, 4).contract_address;
        let token_5_address = deploy_mock_token(beneficiary, 0, 5).contract_address;
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
                    percent: 100 * ROUTE_PERCENT_FACTOR,
                    additional_swap_params: ArrayTrait::new(),
                },
            );
        routes
            .append(
                Route {
                    token_from: token_2_address,
                    token_to: token_2_address,
                    exchange_address,
                    percent: 33 * ROUTE_PERCENT_FACTOR,
                    additional_swap_params: ArrayTrait::new(),
                },
            );
        routes
            .append(
                Route {
                    token_from: token_2_address,
                    token_to: token_3_address,
                    exchange_address,
                    percent: 50 * ROUTE_PERCENT_FACTOR,
                    additional_swap_params: ArrayTrait::new(),
                },
            );
        routes
            .append(
                Route {
                    token_from: token_2_address,
                    token_to: token_4_address,
                    exchange_address,
                    percent: 100 * ROUTE_PERCENT_FACTOR,
                    additional_swap_params: ArrayTrait::new(),
                },
            );
        routes
            .append(
                Route {
                    token_from: token_3_address,
                    token_to: token_5_address,
                    exchange_address,
                    percent: 100 * ROUTE_PERCENT_FACTOR,
                    additional_swap_params: ArrayTrait::new(),
                },
            );
        routes
            .append(
                Route {
                    token_from: token_4_address,
                    token_to: token_3_address,
                    exchange_address,
                    percent: 100 * ROUTE_PERCENT_FACTOR,
                    additional_swap_params: ArrayTrait::new(),
                },
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
                routes,
            );
    }

    #[test]
    #[available_gas(20000000)]
    #[should_panic(expected: ('Unknown exchange', 'ENTRYPOINT_FAILED'))]
    fn should_fail_when_exchange_is_unknown() {
        // Given
        let (exchange, _, _) = deploy_exchange();
        let beneficiary = contract_address_const::<0x12345>();
        let token_from = deploy_mock_token(beneficiary, 10, 1);
        let token_from_address = token_from.contract_address;
        let token_to = deploy_mock_token(beneficiary, 0, 2);
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
                    percent: 100 * ROUTE_PERCENT_FACTOR,
                    additional_swap_params: ArrayTrait::new(),
                },
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
                routes,
            );
    }

    #[test]
    #[available_gas(20000000)]
    #[should_panic(expected: ('Insufficient tokens received', 'ENTRYPOINT_FAILED'))]
    fn should_fail_when_insufficient_tokens_received() {
        // Given
        let (exchange, _, _) = deploy_exchange();
        let beneficiary = contract_address_const::<0x12345>();
        let token_from = deploy_mock_token(beneficiary, 10, 1);
        let token_from_address = token_from.contract_address;
        let token_to = deploy_mock_token(beneficiary, 0, 2);
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
                    percent: 100 * ROUTE_PERCENT_FACTOR,
                    additional_swap_params: ArrayTrait::new(),
                },
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
                routes,
            );
    }

    #[test]
    #[available_gas(20000000)]
    #[should_panic(expected: ('Beneficiary is not the caller', 'ENTRYPOINT_FAILED'))]
    fn should_fail_when_beneficiary_is_not_the_caller() {
        // Given
        let (exchange, _, _) = deploy_exchange();
        let beneficiary = contract_address_const::<0x12345>();
        let token_from = deploy_mock_token(beneficiary, 10, 1);
        let token_from_address = token_from.contract_address;
        let token_to = deploy_mock_token(beneficiary, 0, 2);
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
                    percent: 100 * ROUTE_PERCENT_FACTOR,
                    additional_swap_params: ArrayTrait::new(),
                },
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
                routes,
            );
    }

    #[test]
    #[available_gas(20000000)]
    fn should_call_swap_when_fees_on_sell() {
        // Given
        let (exchange, ownable, fee) = deploy_exchange();
        let beneficiary = contract_address_const::<0x12345>();
        set_contract_address(ownable.get_owner());
        let fees_recipient = contract_address_const::<0x1111>();
        let config = TokenFeeConfig { weight: 10 };
        fee.set_fees_recipient(fees_recipient);
        fee.set_fees_bps_0(20);
        let token_from = deploy_mock_token(beneficiary, 1000, 1);
        let token_from_address = token_from.contract_address;
        let token_to = deploy_mock_token(beneficiary, 0, 2);
        let token_to_address = token_to.contract_address;
        fee.set_token_fee_config(token_from_address, config); // now policy should be FeeOnSell
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
                    percent: 100 * ROUTE_PERCENT_FACTOR,
                    additional_swap_params: ArrayTrait::new(),
                },
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
                routes,
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
            beneficiary: beneficiary,
        };
        assert(event == expected_event, 'invalid swap event');
        assert(pop_log_raw(exchange.contract_address).is_none(), 'no more contract events');

        // Verify transfers
        // Verify integrator's fees at token_from address since policy was FeeOnSell
        let (mut keys, mut data) = pop_log_raw(token_from_address).unwrap();
        let event: Transfer = starknet::Event::deserialize(ref keys, ref data).unwrap();
        let expected_event = Transfer { to: contract_address_const::<0x111>(), amount: 10_u256 };
        assert(event == expected_event, 'invalid token transfer');
        assert(token_from.balanceOf(contract_address_const::<0x111>()) == 10_u256, 'invalid token balance');

        // Verify avnu's fees at token_from addres since policy was FeeOnSell
        let (mut keys, mut data) = pop_log_raw(token_from_address).unwrap();
        let event: Transfer = starknet::Event::deserialize(ref keys, ref data).unwrap();
        let expected_event = Transfer { to: fees_recipient, amount: 2_u256 };
        assert(event == expected_event, 'invalid token transfer');
        assert(token_from.balanceOf(fees_recipient) == 2_u256, 'invalid token balance');

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
    #[available_gas(20000000)]
    fn should_call_swap_when_fees_and_integrator_is_whitelisted_policy_feeonsell() {
        // Given
        let (exchange, ownable, fee) = deploy_exchange();
        let beneficiary = contract_address_const::<0x12345>();
        set_contract_address(ownable.get_owner());
        let fees_recipient = contract_address_const::<0x1111>();
        let integrator = contract_address_const::<'INTEGRATOR'>();
        fee.set_fees_recipient(fees_recipient);
        fee.set_fees_bps_0(20);
        fee.set_whitelisted_integrator(integrator, true);
        let token_from = deploy_mock_token(beneficiary, 1000, 1);
        let token_from_address = token_from.contract_address;
        let config = TokenFeeConfig { weight: 10 };
        fee.set_token_fee_config(token_from_address, config); // now policy should be FeeOnSell
        let token_to = deploy_mock_token(beneficiary, 0, 2);
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
                    percent: 100 * ROUTE_PERCENT_FACTOR,
                    additional_swap_params: ArrayTrait::new(),
                },
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
                integrator,
                routes,
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
            buy_amount: u256 { low: 990, high: 0 },
            beneficiary: beneficiary,
        };
        assert(event == expected_event, 'invalid swap event');
        assert(pop_log_raw(exchange.contract_address).is_none(), 'no more contract events');

        // Verify transfers
        // Verify integrator's fees on token_from address since policy was FeeOnSell
        let (mut keys, mut data) = pop_log_raw(token_from_address).unwrap();
        let event: Transfer = starknet::Event::deserialize(ref keys, ref data).unwrap();
        let expected_event = Transfer { to: integrator, amount: 10_u256 };
        assert(event == expected_event, 'invalid token transfer');
        assert(token_from.balanceOf(integrator) == 10_u256, 'invalid token balance');

        // Verify that beneficiary receives tokens to
        let balance = token_to.balanceOf(beneficiary);
        assert(balance == 990_u256, 'Invalid beneficiary balance');
        let (mut keys, mut data) = pop_log_raw(token_to_address).unwrap();
        let event: Transfer = starknet::Event::deserialize(ref keys, ref data).unwrap();
        let expected_event = Transfer { to: beneficiary, amount: 990_u256 };
        assert(event == expected_event, 'Invalid beneficiary balance');
        assert(pop_log_raw(token_to_address).is_none(), 'no more token_to events');
        assert(pop_log_raw(token_from_address).is_none(), 'no more token_from events');
    }

    // Integrator is whitelisted but integrator fee is less than avnu fee
    #[test]
    #[available_gas(20000000)]
    fn should_call_swap_when_fees_and_integrator_is_whitelisted_policy_feeonsell_2() {
        // Given
        let (exchange, ownable, fee) = deploy_exchange();
        let beneficiary = contract_address_const::<0x12345>();
        set_contract_address(ownable.get_owner());
        let fees_recipient = contract_address_const::<0x1111>();
        let integrator = contract_address_const::<'INTEGRATOR'>();
        fee.set_fees_recipient(fees_recipient);
        fee.set_fees_bps_0(50);
        fee.set_whitelisted_integrator(integrator, true);
        let token_from = deploy_mock_token(beneficiary, 1000, 1);
        let token_from_address = token_from.contract_address;
        let config = TokenFeeConfig { weight: 10 };
        fee.set_token_fee_config(token_from_address, config); // now policy should be FeeOnSell
        let token_to = deploy_mock_token(beneficiary, 0, 2);
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
                    percent: 100 * ROUTE_PERCENT_FACTOR,
                    additional_swap_params: ArrayTrait::new(),
                },
            );
        set_contract_address(beneficiary);
        token_from.approve(exchange.contract_address, token_from_amount);

        // When
        let result = exchange
            .multi_route_swap(
                token_from_address, token_from_amount, token_to_address, token_to_amount, token_to_min_amount, beneficiary, 20, integrator, routes,
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
            buy_amount: u256 { low: 993, high: 0 },
            beneficiary: beneficiary,
        };

        assert(event == expected_event, 'invalid swap event');
        assert(pop_log_raw(exchange.contract_address).is_none(), 'no more contract events');

        // Verify transfers
        // Verify integrator's fees on token_from address since policy was FeeOnSell
        let (mut keys, mut data) = pop_log_raw(token_from_address).unwrap();
        let event: Transfer = starknet::Event::deserialize(ref keys, ref data).unwrap();
        let expected_event = Transfer { to: integrator, amount: 2_u256 };
        assert(event == expected_event, 'invalid token transfer');
        assert(token_from.balanceOf(integrator) == 2_u256, 'invalid token balance');

        // Verify avnu's fees at token_from addres since policy was FeeOnSell
        let (mut keys, mut data) = pop_log_raw(token_from_address).unwrap();
        let event: Transfer = starknet::Event::deserialize(ref keys, ref data).unwrap();
        let expected_event = Transfer { to: fees_recipient, amount: 5_u256 };
        assert(event == expected_event, 'invalid token transfer');
        assert(token_from.balanceOf(fees_recipient) == 5_u256, 'invalid token balance');

        // Verify that beneficiary receives tokens to
        let balance = token_to.balanceOf(beneficiary);
        assert(balance == 993_u256, 'Invalid beneficiary balance');
        let (mut keys, mut data) = pop_log_raw(token_to_address).unwrap();
        let event: Transfer = starknet::Event::deserialize(ref keys, ref data).unwrap();
        let expected_event = Transfer { to: beneficiary, amount: 993_u256 };
        assert(event == expected_event, 'Invalid beneficiary balance');
        assert(pop_log_raw(token_to_address).is_none(), 'no more token_to events');
        assert(pop_log_raw(token_from_address).is_none(), 'no more token_from events');
    }

    #[test]
    #[available_gas(20000000)]
    fn should_call_swap_when_fees_and_multiple_routes_policy_feeonsell() {
        // Given
        let (exchange, ownable, fee) = deploy_exchange();
        let beneficiary = contract_address_const::<0x12345>();
        set_contract_address(ownable.get_owner());
        let fees_recipient = contract_address_const::<0x1111>();
        fee.set_fees_recipient(fees_recipient);
        fee.set_fees_bps_1(20);
        fee.set_fees_bps_0(10);
        let token_from = deploy_mock_token(beneficiary, 1000, 1);
        let token_from_address = token_from.contract_address;
        let config = TokenFeeConfig { weight: 20 };
        fee.set_token_fee_config(token_from_address, config); // now policy should be FeeOnSell
        let token_to = deploy_mock_token(beneficiary, 0, 2);
        let token_to_address = token_to.contract_address;
        let config = TokenFeeConfig { weight: 10 };
        fee.set_token_fee_config(token_to_address, config);
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
                    percent: 60 * ROUTE_PERCENT_FACTOR,
                    additional_swap_params: ArrayTrait::new(),
                },
            );
        routes
            .append(
                Route {
                    token_from: token_from_address,
                    token_to: token_to_address,
                    exchange_address: contract_address_const::<0x12>(),
                    percent: 100 * ROUTE_PERCENT_FACTOR,
                    additional_swap_params: ArrayTrait::new(),
                },
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
                routes,
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
            beneficiary: beneficiary,
        };

        assert(event == expected_event, 'invalid swap event');
        assert(pop_log_raw(exchange.contract_address).is_none(), 'no more contract events');

        // Verify transfers
        // Verify integrator's fees
        let (mut keys, mut data) = pop_log_raw(token_from_address).unwrap();
        let event: Transfer = starknet::Event::deserialize(ref keys, ref data).unwrap();
        let expected_event = Transfer { to: contract_address_const::<0x111>(), amount: 10_u256 };
        assert(event == expected_event, 'invalid token transfer');

        // Verify avnu's fees
        let (mut keys, mut data) = pop_log_raw(token_from_address).unwrap();
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
}

mod SwapExactTokenTo {
    use super::{
        ContractAddress, IERC20DispatcherTrait, IExchangeDispatcher, IExchangeDispatcherTrait, IFeeDispatcherTrait, IOwnableDispatcherTrait,
        ROUTE_PERCENT_FACTOR, Route, Swap, Transfer, contract_address_const, deploy_exchange, deploy_mock_token, pop_log_raw, set_contract_address,
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
        expected_event: Swap,
    }

    #[test]
    #[available_gas(20000000)]
    fn should_swap_when_setting_token_to() {
        // Given
        let (exchange, ownable, fee) = deploy_exchange();
        let beneficiary = contract_address_const::<0x12345>();
        let token_from = deploy_mock_token(beneficiary, 120000, 1);
        let token_from_address = token_from.contract_address;
        let token_to = deploy_mock_token(beneficiary, 0, 2);
        let token_to_address = token_to.contract_address;
        set_contract_address(ownable.get_owner());
        let fees_recipient = contract_address_const::<0x1111>();
        fee.set_fees_recipient(fees_recipient);
        fee.set_swap_exact_token_to_fees_bps(5_u128);
        let token_from_max_amount = u256 { low: 120000, high: 0 };
        let token_from_amount = u256 { low: 8000, high: 0 };
        let token_to_amount = u256 { low: 100000, high: 0 };
        let mut routes = ArrayTrait::new();
        routes
            .append(
                Route {
                    token_from: token_from_address,
                    token_to: token_to_address,
                    exchange_address: contract_address_const::<0x12>(),
                    percent: 100 * ROUTE_PERCENT_FACTOR,
                    additional_swap_params: ArrayTrait::new(),
                },
            );
        set_contract_address(beneficiary);
        token_from.approve(exchange.contract_address, token_from_max_amount);

        // When
        let result = exchange
            .swap_exact_token_to(
                token_from_address, token_from_amount, token_from_max_amount, token_to_address, token_to_amount, beneficiary, routes,
            );

        // Then
        assert(result == true, 'invalid result');
        let (mut keys, mut data) = pop_log_raw(exchange.contract_address).unwrap();
        let event: Swap = starknet::Event::deserialize(ref keys, ref data).unwrap();
        let expected_event = Swap {
            taker_address: beneficiary,
            sell_address: token_from_address,
            sell_amount: 100050,
            buy_address: token_to_address,
            buy_amount: token_to_amount,
            beneficiary: beneficiary,
        };
        assert(event == expected_event, 'invalid swap event');
        assert(pop_log_raw(exchange.contract_address).is_none(), 'no more events');

        // Verify that beneficiary receives tokens to
        let balance = token_to.balanceOf(beneficiary);
        assert(balance == 100000_u256, 'Invalid beneficiary balance');
        let balance = token_from.balanceOf(beneficiary);
        assert(balance == 19950_u256, 'Invalid beneficiary balance');

        let (mut keys, mut data) = pop_log_raw(token_to_address).unwrap();
        let event: Transfer = starknet::Event::deserialize(ref keys, ref data).unwrap();
        let expected_event = Transfer { to: beneficiary, amount: 100000_u256 };
        assert(event == expected_event, 'Invalid transfer event');

        // Verify avnu's fees
        let (mut keys, mut data) = pop_log_raw(token_to_address).unwrap();
        let event: Transfer = starknet::Event::deserialize(ref keys, ref data).unwrap();
        let expected_event = Transfer { to: fees_recipient, amount: 50_u256 };
        assert(event == expected_event, 'invalid avnu fees transfer');

        assert(pop_log_raw(token_to_address).is_none(), 'no more token_to events');
        assert(pop_log_raw(token_from_address).is_none(), 'no more token_from events');
    }

    #[test]
    #[available_gas(20000000)]
    fn should_swap_when_setting_token_to_when_no_fees() {
        // Given
        let (exchange, ownable, fee) = deploy_exchange();
        let beneficiary = contract_address_const::<0x12345>();
        let token_from = deploy_mock_token(beneficiary, 120000, 1);
        let token_from_address = token_from.contract_address;
        let token_to = deploy_mock_token(beneficiary, 0, 2);
        let token_to_address = token_to.contract_address;
        set_contract_address(ownable.get_owner());
        let fees_recipient = contract_address_const::<0x1111>();
        fee.set_fees_recipient(fees_recipient);
        let token_from_max_amount = u256 { low: 120000, high: 0 };
        let token_from_amount = u256 { low: 8000, high: 0 };
        let token_to_amount = u256 { low: 100000, high: 0 };
        let mut routes = ArrayTrait::new();
        routes
            .append(
                Route {
                    token_from: token_from_address,
                    token_to: token_to_address,
                    exchange_address: contract_address_const::<0x12>(),
                    percent: 100 * ROUTE_PERCENT_FACTOR,
                    additional_swap_params: ArrayTrait::new(),
                },
            );
        set_contract_address(beneficiary);
        token_from.approve(exchange.contract_address, token_from_max_amount);

        // When
        let result = exchange
            .swap_exact_token_to(
                token_from_address, token_from_amount, token_from_max_amount, token_to_address, token_to_amount, beneficiary, routes,
            );

        // Then
        assert(result == true, 'invalid result');
        let (mut keys, mut data) = pop_log_raw(exchange.contract_address).unwrap();
        let event: Swap = starknet::Event::deserialize(ref keys, ref data).unwrap();
        let expected_event = Swap {
            taker_address: beneficiary,
            sell_address: token_from_address,
            sell_amount: 100000,
            buy_address: token_to_address,
            buy_amount: token_to_amount,
            beneficiary: beneficiary,
        };
        assert(event == expected_event, 'invalid swap event');
        assert(pop_log_raw(exchange.contract_address).is_none(), 'no more events');

        // Verify that beneficiary receives tokens to
        let balance = token_to.balanceOf(beneficiary);
        assert(balance == 100000_u256, 'Invalid beneficiary balance');
        let balance = token_from.balanceOf(beneficiary);
        assert(balance == 20000_u256, 'Invalid beneficiary balance');

        let (mut keys, mut data) = pop_log_raw(token_to_address).unwrap();
        let event: Transfer = starknet::Event::deserialize(ref keys, ref data).unwrap();
        let expected_event = Transfer { to: beneficiary, amount: 100000_u256 };
        assert(event == expected_event, 'Invalid transfer event');

        assert(pop_log_raw(token_to_address).is_none(), 'no more token_to events');
        assert(pop_log_raw(token_from_address).is_none(), 'no more token_from events');
    }

    #[test]
    #[available_gas(20000000)]
    #[should_panic(expected: ('Residual tokens', 'ENTRYPOINT_FAILED'))]
    fn should_throw_error_when_residual_tokens() {
        // Given
        let (exchange, ownable, fee) = deploy_exchange();
        let beneficiary = contract_address_const::<0x12345>();
        let token_from = deploy_mock_token(beneficiary, 10, 1);
        let token_from_address = token_from.contract_address;
        let token_to = deploy_mock_token(beneficiary, 0, 2);
        let token_to_address = token_to.contract_address;
        let token_from_max_amount = u256 { low: 10, high: 0 };
        let token_from_amount = u256 { low: 9, high: 0 };
        set_contract_address(ownable.get_owner());
        let fees_recipient = contract_address_const::<0x1111>();
        fee.set_fees_recipient(fees_recipient);
        let token_to_amount = u256 { low: 1, high: 0 };
        let mut routes = ArrayTrait::new();
        routes
            .append(
                Route {
                    token_from: token_from_address,
                    token_to: token_to_address,
                    exchange_address: contract_address_const::<0x12>(),
                    percent: 40 * ROUTE_PERCENT_FACTOR,
                    additional_swap_params: ArrayTrait::new(),
                },
            );
        set_contract_address(beneficiary);
        token_from.approve(exchange.contract_address, token_from_max_amount);

        // When
        exchange
            .swap_exact_token_to(
                token_from_address, token_from_amount, token_from_max_amount, token_to_address, token_to_amount, beneficiary, routes,
            );
    }

    #[test]
    #[available_gas(20000000)]
    #[should_panic(expected: ('Token from amount is 0', 'ENTRYPOINT_FAILED'))]
    fn should_throw_error_when_token_from_amount_is_0() {
        // Given
        let (exchange, _, _) = deploy_exchange();
        let beneficiary = contract_address_const::<0x12345>();
        let token_from = deploy_mock_token(beneficiary, 10, 1);
        let token_from_address = token_from.contract_address;
        let token_to = deploy_mock_token(beneficiary, 0, 2);
        let token_to_address = token_to.contract_address;
        let token_from_max_amount = u256 { low: 10, high: 0 };
        let token_from_amount = u256 { low: 0, high: 0 };
        let token_to_amount = u256 { low: 9, high: 0 };
        let mut routes = ArrayTrait::new();
        routes
            .append(
                Route {
                    token_from: token_from_address,
                    token_to: token_to_address,
                    exchange_address: contract_address_const::<0x12>(),
                    percent: 100 * ROUTE_PERCENT_FACTOR,
                    additional_swap_params: ArrayTrait::new(),
                },
            );
        set_contract_address(beneficiary);
        token_from.approve(exchange.contract_address, token_from_max_amount);

        // When & Then
        exchange
            .swap_exact_token_to(
                token_from_address, token_from_amount, token_from_max_amount, token_to_address, token_to_amount, beneficiary, routes,
            );
    }

    #[test]
    #[available_gas(20000000)]
    #[should_panic(expected: ('Token from balance is too low', 'ENTRYPOINT_FAILED'))]
    fn should_throw_error_when_caller_balance_is_too_low() {
        // Given
        let (exchange, _, _) = deploy_exchange();
        let beneficiary = contract_address_const::<0x12345>();
        let token_from = deploy_mock_token(beneficiary, 5, 1);
        let token_from_address = token_from.contract_address;
        let token_to = deploy_mock_token(beneficiary, 0, 2);
        let token_to_address = token_to.contract_address;
        let token_from_max_amount = u256 { low: 10, high: 0 };
        let token_from_amount = u256 { low: 9, high: 0 };
        let token_to_amount = u256 { low: 9, high: 0 };
        let mut routes = ArrayTrait::new();
        routes
            .append(
                Route {
                    token_from: token_from_address,
                    token_to: token_to_address,
                    exchange_address: contract_address_const::<0x12>(),
                    percent: 100 * ROUTE_PERCENT_FACTOR,
                    additional_swap_params: ArrayTrait::new(),
                },
            );
        set_contract_address(beneficiary);
        token_from.approve(exchange.contract_address, token_from_max_amount);

        // When & Then
        exchange
            .swap_exact_token_to(
                token_from_address, token_from_amount, token_from_max_amount, token_to_address, token_to_amount, beneficiary, routes,
            );
    }

    #[test]
    #[should_panic(expected: ('Fee recipient is empty', 'ENTRYPOINT_FAILED'))]
    #[available_gas(20000000)]
    fn should_throw_error_fee_recipient_is_empty() {
        // Given
        let (exchange, ownable, fee) = deploy_exchange();
        let beneficiary = contract_address_const::<0x12345>();
        let token_from = deploy_mock_token(beneficiary, 10, 1);
        let token_from_address = token_from.contract_address;
        let token_to = deploy_mock_token(beneficiary, 0, 2);
        let token_to_address = token_to.contract_address;
        let token_from_max_amount = u256 { low: 10, high: 0 };
        let token_from_amount = u256 { low: 10, high: 0 };
        let token_to_amount = u256 { low: 9, high: 0 };
        set_contract_address(ownable.get_owner());
        let fees_recipient = contract_address_const::<0x0>();
        fee.set_fees_recipient(fees_recipient);
        let mut routes = ArrayTrait::new();
        routes
            .append(
                Route {
                    token_from: token_from_address,
                    token_to: token_to_address,
                    exchange_address: contract_address_const::<0x12>(),
                    percent: 100 * ROUTE_PERCENT_FACTOR,
                    additional_swap_params: ArrayTrait::new(),
                },
            );
        set_contract_address(beneficiary);
        token_from.approve(exchange.contract_address, token_from_max_amount);

        // When & Then
        exchange
            .swap_exact_token_to(
                token_from_address, token_from_amount, token_from_max_amount, token_to_address, token_to_amount, beneficiary, routes,
            );
    }

    #[test]
    #[should_panic(expected: ('Routes is empty', 'ENTRYPOINT_FAILED'))]
    #[available_gas(20000000)]
    fn should_throw_error_when_routes_is_empty() {
        // Given
        let (exchange, _, _) = deploy_exchange();
        let beneficiary = contract_address_const::<0x12345>();
        let token_from = deploy_mock_token(beneficiary, 10, 1);
        let token_from_address = token_from.contract_address;
        let token_to = deploy_mock_token(beneficiary, 0, 2);
        let token_to_address = token_to.contract_address;
        let token_from_max_amount = u256 { low: 10, high: 0 };
        let token_from_amount = u256 { low: 9, high: 0 };
        let token_to_amount = u256 { low: 9, high: 0 };
        let mut routes = ArrayTrait::new();
        set_contract_address(beneficiary);
        token_from.approve(exchange.contract_address, token_from_max_amount);

        // When & Then
        exchange
            .swap_exact_token_to(
                token_from_address, token_from_amount, token_from_max_amount, token_to_address, token_to_amount, beneficiary, routes,
            );
    }

    #[test]
    #[should_panic(expected: ('Invalid token from', 'ENTRYPOINT_FAILED'))]
    #[available_gas(20000000)]
    fn should_throw_error_when_first_token_from_is_not_token_from() {
        // Given
        let (exchange, _, _) = deploy_exchange();
        let beneficiary = contract_address_const::<0x12345>();
        let token_from = deploy_mock_token(beneficiary, 10, 1);
        let token_from_address = token_from.contract_address;
        let token_from_address_2 = deploy_mock_token(beneficiary, 10, 2).contract_address;
        let token_to = deploy_mock_token(beneficiary, 0, 3);
        let token_to_address = token_to.contract_address;
        let token_from_max_amount = u256 { low: 10, high: 0 };
        let token_from_amount = u256 { low: 9, high: 0 };
        let token_to_amount = u256 { low: 9, high: 0 };
        let mut routes = ArrayTrait::new();
        routes
            .append(
                Route {
                    token_from: token_from_address_2,
                    token_to: token_to_address,
                    exchange_address: contract_address_const::<0x12>(),
                    percent: 100 * ROUTE_PERCENT_FACTOR,
                    additional_swap_params: ArrayTrait::new(),
                },
            );
        set_contract_address(beneficiary);
        token_from.approve(exchange.contract_address, token_from_max_amount);

        // When & Then
        exchange
            .swap_exact_token_to(
                token_from_address, token_from_amount, token_from_max_amount, token_to_address, token_to_amount, beneficiary, routes,
            );
    }

    #[test]
    #[available_gas(20000000)]
    #[should_panic(expected: ('Invalid token to', 'ENTRYPOINT_FAILED'))]
    fn should_throw_error_when_last_token_to_is_not_token_to() {
        // Given
        let (exchange, _, _) = deploy_exchange();
        let beneficiary = contract_address_const::<0x12345>();
        let token_1 = deploy_mock_token(beneficiary, 10, 1);
        let token_1_address = token_1.contract_address;
        let token_2_address = deploy_mock_token(beneficiary, 0, 2).contract_address;
        let token_3_address = deploy_mock_token(beneficiary, 0, 3).contract_address;
        let token_4_address = deploy_mock_token(beneficiary, 0, 4).contract_address;
        let token_5_address = deploy_mock_token(beneficiary, 0, 5).contract_address;
        let beneficiary = contract_address_const::<0x12345>();
        let token_from_max_amount = u256 { low: 10, high: 0 };
        let token_from_amount = u256 { low: 9, high: 0 };
        let token_to_amount = u256 { low: 9, high: 0 };
        let mut routes = ArrayTrait::new();
        let exchange_address = contract_address_const::<0x12>();
        routes
            .append(
                Route {
                    token_from: token_1_address,
                    token_to: token_2_address,
                    exchange_address,
                    percent: 100 * ROUTE_PERCENT_FACTOR,
                    additional_swap_params: ArrayTrait::new(),
                },
            );
        routes
            .append(
                Route {
                    token_from: token_2_address,
                    token_to: token_2_address,
                    exchange_address,
                    percent: 33 * ROUTE_PERCENT_FACTOR,
                    additional_swap_params: ArrayTrait::new(),
                },
            );
        routes
            .append(
                Route {
                    token_from: token_2_address,
                    token_to: token_3_address,
                    exchange_address,
                    percent: 50 * ROUTE_PERCENT_FACTOR,
                    additional_swap_params: ArrayTrait::new(),
                },
            );
        routes
            .append(
                Route {
                    token_from: token_2_address,
                    token_to: token_4_address,
                    exchange_address,
                    percent: 100 * ROUTE_PERCENT_FACTOR,
                    additional_swap_params: ArrayTrait::new(),
                },
            );
        routes
            .append(
                Route {
                    token_from: token_3_address,
                    token_to: token_5_address,
                    exchange_address,
                    percent: 100 * ROUTE_PERCENT_FACTOR,
                    additional_swap_params: ArrayTrait::new(),
                },
            );
        routes
            .append(
                Route {
                    token_from: token_4_address,
                    token_to: token_3_address,
                    exchange_address,
                    percent: 100 * ROUTE_PERCENT_FACTOR,
                    additional_swap_params: ArrayTrait::new(),
                },
            );
        set_contract_address(beneficiary);
        token_1.approve(exchange.contract_address, token_from_max_amount);

        // When & Then
        exchange
            .swap_exact_token_to(token_1_address, token_from_amount, token_from_max_amount, token_5_address, token_to_amount, beneficiary, routes);
    }

    #[test]
    #[available_gas(20000000)]
    #[should_panic(expected: ('Insufficient token from amount', 'ENTRYPOINT_FAILED'))]
    fn should_fail_when_not_enough_token_from() {
        // Given
        let (exchange, _, _) = deploy_exchange();
        let beneficiary = contract_address_const::<0x12345>();
        let token_from = deploy_mock_token(beneficiary, 10, 1);
        let token_from_address = token_from.contract_address;
        let token_to = deploy_mock_token(beneficiary, 0, 2);
        let token_to_address = token_to.contract_address;
        let token_from_max_amount = u256 { low: 10, high: 0 };
        let token_from_amount = u256 { low: 9, high: 0 };
        let token_to_amount = u256 { low: 11, high: 0 };
        let mut routes = ArrayTrait::new();
        routes
            .append(
                Route {
                    token_from: token_from_address,
                    token_to: token_to_address,
                    exchange_address: contract_address_const::<0x12>(),
                    percent: 100 * ROUTE_PERCENT_FACTOR,
                    additional_swap_params: ArrayTrait::new(),
                },
            );
        set_contract_address(beneficiary);
        token_from.approve(exchange.contract_address, token_from_max_amount);

        // When & Then
        exchange
            .swap_exact_token_to(
                token_from_address, token_from_amount, token_from_max_amount, token_to_address, token_to_amount, beneficiary, routes,
            );
    }

    #[test]
    #[available_gas(20000000)]
    #[should_panic(expected: ('Beneficiary is not the caller', 'ENTRYPOINT_FAILED'))]
    fn should_fail_when_beneficiary_is_not_the_caller() {
        // Given
        let (exchange, _, _) = deploy_exchange();
        let beneficiary = contract_address_const::<0x12345>();
        let token_from = deploy_mock_token(beneficiary, 10, 1);
        let token_from_address = token_from.contract_address;
        let token_to = deploy_mock_token(beneficiary, 0, 2);
        let token_to_address = token_to.contract_address;
        let token_from_max_amount = u256 { low: 10, high: 0 };
        let token_from_amount = u256 { low: 9, high: 0 };
        let token_to_amount = u256 { low: 9, high: 0 };
        let mut routes = ArrayTrait::new();
        routes
            .append(
                Route {
                    token_from: token_from_address,
                    token_to: token_to_address,
                    exchange_address: contract_address_const::<0x12>(),
                    percent: 100 * ROUTE_PERCENT_FACTOR,
                    additional_swap_params: ArrayTrait::new(),
                },
            );

        // When & Then
        exchange
            .swap_exact_token_to(
                token_from_address, token_from_amount, token_from_max_amount, token_to_address, token_to_amount, beneficiary, routes,
            );
    }
}

mod UpgradeClassAndMigration {
    use super::{
        Exchange, IERC20DispatcherTrait, IExchangeDispatcher, IExchangeDispatcherTrait, IFeeDispatcher, IFeeDispatcherTrait,
        IOldExchangeDispatcherTrait, IOwnableDispatcher, IOwnableDispatcherTrait, ROUTE_PERCENT_FACTOR, Route, Swap, Transfer, contract_address_const,
        deploy_mock_token, deploy_old_exchange, pop_log_raw, set_contract_address,
    };

    #[test]
    fn upgrade_class_check_storage_without_initialization() {
        //Given
        let (exchange, exchange_address) = deploy_old_exchange();
        exchange.set_fees_bps_0(10);
        exchange.set_fees_bps_1(20);
        exchange.set_swap_exact_token_to_fees_bps(30);

        // When
        exchange.upgrade_class(Exchange::TEST_CLASS_HASH.try_into().unwrap());
        let fee = IFeeDispatcher { contract_address: exchange_address };

        //Then
        assert(fee.get_fees_bps_0() == 10_u128, 'invalid fees bps');
        assert(fee.get_fees_bps_1() == 20_u128, 'invalid fees bps');
        assert(fee.get_swap_exact_token_to_fees_bps() == 30_u128, 'invalid fees bps');
        let fee_recipient = contract_address_const::<0x2>();
        assert(fee.get_fees_recipient() == fee_recipient, 'invalid fee recipient');
    }

    #[test]
    fn upgrade_class_check_storage_with_initialization() {
        // Given
        let (exchange, exchange_address) = deploy_old_exchange();
        exchange.set_fees_bps_0(10);
        exchange.set_fees_bps_1(20);
        exchange.set_swap_exact_token_to_fees_bps(30);
        let owner = contract_address_const::<0x1>();
        set_contract_address(owner);
        // When
        exchange.upgrade_class(Exchange::TEST_CLASS_HASH.try_into().unwrap());
        let new_exchange = IExchangeDispatcher { contract_address: exchange_address };
        let new_fee_recipient = contract_address_const::<0x20>();
        let ownable_owner_initial = contract_address_const::<0x0>();
        let new_owner = contract_address_const::<'NEW_OWNER'>();
        let ownable = IOwnableDispatcher { contract_address: exchange_address };
        assert(ownable.get_owner() == ownable_owner_initial, 'invalid initial owner');
        // initialize function is not gated behind assert_only_owner
        set_contract_address(contract_address_const::<'RANDOM'>());
        new_exchange.initialize(new_owner, new_fee_recipient, 50, 100, 100);

        // Then
        let fee = IFeeDispatcher { contract_address: exchange_address };
        assert(fee.get_fees_bps_0() == 50, 'invalid fees bps');
        assert(fee.get_fees_bps_1() == 100_u128, 'invalid fees bps');
        assert(fee.get_swap_exact_token_to_fees_bps() == 100_u128, 'invalid fees bps');
        assert(fee.get_fees_recipient() == new_fee_recipient, 'invalid fee recipient');

        assert(ownable.get_owner() == new_owner, 'invalid new owner');
    }

    #[test]
    fn should_not_panic_if_owner_only_function_called_after_initialize() {
        // Given
        let (exchange, exchange_address) = deploy_old_exchange();
        exchange.set_fees_bps_0(10);
        exchange.set_fees_bps_1(20);
        exchange.set_swap_exact_token_to_fees_bps(30);
        let owner = contract_address_const::<0x1>();
        set_contract_address(owner);

        // When
        exchange.upgrade_class(Exchange::TEST_CLASS_HASH.try_into().unwrap());
        let new_exchange = IExchangeDispatcher { contract_address: exchange_address };
        let new_fee_recipient = contract_address_const::<0x20>();
        let new_owner = contract_address_const::<'NEW_OWNER'>();
        new_exchange.initialize(new_owner, new_fee_recipient, 50, 100, 100);
        set_contract_address(new_owner);

        // Then
        new_exchange.set_adapter_class_hash(exchange_address, Exchange::TEST_CLASS_HASH.try_into().unwrap());
        assert(new_exchange.get_adapter_class_hash(exchange_address) == Exchange::TEST_CLASS_HASH.try_into().unwrap(), 'invalid class hash');
    }

    #[test]
    #[should_panic(expected: ('Fees are too high', 'ENTRYPOINT_FAILED'))]
    fn should_panic_if_initialize_called_with_too_high_fees_bps() {
        // Given
        let (exchange, exchange_address) = deploy_old_exchange();
        exchange.set_fees_bps_0(10);
        exchange.set_fees_bps_1(20);
        exchange.set_swap_exact_token_to_fees_bps(30);
        let owner = contract_address_const::<0x1>();
        set_contract_address(owner);

        // When & Then
        exchange.upgrade_class(Exchange::TEST_CLASS_HASH.try_into().unwrap());
        let new_exchange = IExchangeDispatcher { contract_address: exchange_address };
        let new_fee_recipient = contract_address_const::<0x20>();
        let new_owner = contract_address_const::<'NEW_OWNER'>();

        new_exchange.initialize(new_owner, new_fee_recipient, 100, 101, 100);
    }

    #[test]
    #[should_panic(expected: ('Owner already initialized', 'ENTRYPOINT_FAILED'))]
    fn should_panic_if_initialize_called_twice_by_owner() {
        // Given
        let (exchange, exchange_address) = deploy_old_exchange();
        exchange.set_fees_bps_0(10);
        exchange.set_fees_bps_1(20);
        exchange.set_swap_exact_token_to_fees_bps(30);
        let owner = contract_address_const::<0x1>();
        set_contract_address(owner);

        // When & Then
        exchange.upgrade_class(Exchange::TEST_CLASS_HASH.try_into().unwrap());
        let new_exchange = IExchangeDispatcher { contract_address: exchange_address };
        let new_fee_recipient = contract_address_const::<0x20>();
        let new_owner = contract_address_const::<'NEW_OWNER'>();

        new_exchange.initialize(new_owner, new_fee_recipient, 50, 100, 50);
        new_exchange.initialize(new_owner, new_fee_recipient, 50, 100, 50); // Not allowed
    }

    #[test]
    #[should_panic(expected: ('Owner already initialized', 'ENTRYPOINT_FAILED'))]
    fn should_panic_if_initialize_called_twice_by_anyone() {
        // Given
        let (exchange, exchange_address) = deploy_old_exchange();
        exchange.set_fees_bps_0(10);
        exchange.set_fees_bps_1(20);
        exchange.set_swap_exact_token_to_fees_bps(30);
        let owner = contract_address_const::<0x1>();
        set_contract_address(owner);

        // When & Then
        exchange.upgrade_class(Exchange::TEST_CLASS_HASH.try_into().unwrap());
        let new_exchange = IExchangeDispatcher { contract_address: exchange_address };
        let new_fee_recipient = contract_address_const::<0x20>();
        let new_owner = contract_address_const::<'NEW_OWNER'>();

        new_exchange.initialize(new_owner, new_fee_recipient, 50, 100, 50);
        set_contract_address(contract_address_const::<'RANDOM'>());
        new_exchange.initialize(new_owner, new_fee_recipient, 50, 100, 50); // Not allowed
    }

    #[test]
    #[should_panic(expected: ('Caller is not the owner', 'ENTRYPOINT_FAILED'))]
    fn should_panic_if_owner_only_function_called_before_initialize() {
        // Given
        let (exchange, exchange_address) = deploy_old_exchange();
        exchange.set_fees_bps_0(10);
        exchange.set_fees_bps_1(20);
        exchange.set_swap_exact_token_to_fees_bps(30);
        let owner = contract_address_const::<0x1>();
        set_contract_address(owner);

        // When & Then
        exchange.upgrade_class(Exchange::TEST_CLASS_HASH.try_into().unwrap());
        let new_exchange = IExchangeDispatcher { contract_address: exchange_address };

        // Using dummy values here
        new_exchange.set_adapter_class_hash(exchange_address, Exchange::TEST_CLASS_HASH.try_into().unwrap());
    }

    #[test]
    #[should_panic(expected: ('ENTRYPOINT_NOT_FOUND', 'ENTRYPOINT_FAILED'))]
    fn should_panic_if_old_function_called_after_upgrade() {
        // Given
        let (exchange, _) = deploy_old_exchange();
        exchange.set_fees_bps_0(10);
        exchange.set_fees_bps_1(20);
        exchange.set_swap_exact_token_to_fees_bps(30);
        let owner = contract_address_const::<0x1>();
        set_contract_address(owner);

        // When & Then
        exchange.upgrade_class(Exchange::TEST_CLASS_HASH.try_into().unwrap());
        exchange.get_fees_active();
    }

    #[test]
    #[available_gas(20000000)]
    fn should_call_swap_when_fees_after_upgrade_before_initialize() {
        // Given
        let (exchange, _) = deploy_old_exchange();
        let owner = contract_address_const::<0x1>();
        set_contract_address(owner);

        // When
        exchange.upgrade_class(Exchange::TEST_CLASS_HASH.try_into().unwrap());
        let beneficiary = contract_address_const::<0x12345>();

        let token_from = deploy_mock_token(beneficiary, 1000, 1);
        let token_from_address = token_from.contract_address;
        let token_to = deploy_mock_token(beneficiary, 0, 2);
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
                    percent: 100 * ROUTE_PERCENT_FACTOR,
                    additional_swap_params: ArrayTrait::new(),
                },
            );
        set_contract_address(beneficiary);
        token_from.approve(exchange.contract_address, token_from_amount);

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
                routes,
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
            buy_amount: u256 { low: 990, high: 0 },
            beneficiary: beneficiary,
        };
        assert(event == expected_event, 'invalid swap event');
        assert(pop_log_raw(exchange.contract_address).is_none(), 'no more contract events');

        // Verify transfers
        // Verify integrator's fees
        let (mut keys, mut data) = pop_log_raw(token_to_address).unwrap();
        let event: Transfer = starknet::Event::deserialize(ref keys, ref data).unwrap();
        let expected_event = Transfer { to: contract_address_const::<0x111>(), amount: 10_u256 };
        assert(event == expected_event, 'invalid token transfer');

        // Verify that beneficiary receives tokens to
        let balance = token_to.balanceOf(beneficiary);
        assert(balance == 990_u256, 'Invalid beneficiary balance');
        let (mut keys, mut data) = pop_log_raw(token_to_address).unwrap();
        let event: Transfer = starknet::Event::deserialize(ref keys, ref data).unwrap();
        let expected_event = Transfer { to: beneficiary, amount: 990_u256 };
        assert(event == expected_event, 'Invalid beneficiary balance');
        assert(pop_log_raw(token_to_address).is_none(), 'no more token_to events');
        assert(pop_log_raw(token_from_address).is_none(), 'no more token_from events');
    }

    #[test]
    #[available_gas(20000000)]
    fn should_call_swap_when_fees_after_upgrade_after_initialize() {
        // Given
        let (exchange, exchange_address) = deploy_old_exchange();
        let owner = contract_address_const::<0x1>();
        set_contract_address(owner);

        // When
        exchange.upgrade_class(Exchange::TEST_CLASS_HASH.try_into().unwrap());
        let new_exchange = IExchangeDispatcher { contract_address: exchange_address };
        let new_fee_recipient = contract_address_const::<0x20>();
        let new_owner = contract_address_const::<'NEW_OWNER'>();

        new_exchange.initialize(new_owner, new_fee_recipient, 0, 0, 50);
        let beneficiary = contract_address_const::<0x12345>();
        set_contract_address(new_owner);
        let fees_recipient = contract_address_const::<0x1111>();
        let fee = IFeeDispatcher { contract_address: exchange_address };
        fee.set_fees_recipient(fees_recipient);
        fee.set_fees_bps_0(20);
        let token_from = deploy_mock_token(beneficiary, 1000, 1);
        let token_from_address = token_from.contract_address;
        let token_to = deploy_mock_token(beneficiary, 0, 2);
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
                    percent: 100 * ROUTE_PERCENT_FACTOR,
                    additional_swap_params: ArrayTrait::new(),
                },
            );
        set_contract_address(beneficiary);
        token_from.approve(exchange.contract_address, token_from_amount);

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
                routes,
            );

        // Then
        assert(result == true, 'invalid result');

        let (_, _) = pop_log_raw(exchange.contract_address).unwrap(); // initialize
        let (mut keys, mut data) = pop_log_raw(exchange.contract_address).unwrap();
        let event: Swap = starknet::Event::deserialize(ref keys, ref data).unwrap();
        let expected_event = Swap {
            taker_address: beneficiary,
            sell_address: token_from_address,
            sell_amount: token_from_amount,
            buy_address: token_to_address,
            buy_amount: u256 { low: 988, high: 0 },
            beneficiary: beneficiary,
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
}
