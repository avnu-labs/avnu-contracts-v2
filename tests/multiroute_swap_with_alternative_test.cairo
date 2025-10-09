
use avnu::components::fee::{IFeeDispatcher, IFeeDispatcherTrait, TokenFeeConfig};
use avnu::exchange::Exchange;
use avnu::exchange::Exchange::Swap;
use avnu::exchange::{IExchangeDispatcher, IExchangeDispatcherTrait};
use avnu::models::{BranchSwap, AlternativeSwap, DirectSwap, Route, RouteSwap};
use avnu_lib::components::ownable::{IOwnableDispatcher, IOwnableDispatcherTrait};
use avnu_lib::interfaces::erc20::IERC20DispatcherTrait;
use starknet::class_hash::class_hash_const;
use starknet::testing::{pop_log_raw, set_contract_address};
use starknet::{ContractAddress, contract_address_const};
use super::helper::{deploy_exchange, deploy_mock_layer_akira, deploy_mock_token};
use super::mocks::mock_erc20::MockERC20::Transfer;
use super::mocks::mock_amm::{ MockPriceFunction, MockConstantPriceFunction, MockUniV2PriceFunction };

const ROUTE_PERCENT_FACTOR: u128 = 10000000000;

mod SwapWithAlternative {
    use super::{
        AlternativeSwap, BranchSwap, ContractAddress, DirectSwap, IERC20DispatcherTrait, IExchangeDispatcher, IExchangeDispatcherTrait,
        IFeeDispatcherTrait, IOwnableDispatcherTrait, ROUTE_PERCENT_FACTOR, Route, RouteSwap, Swap, TokenFeeConfig, Transfer, contract_address_const,
        deploy_exchange, deploy_mock_token, pop_log_raw, set_contract_address, MockPriceFunction, MockConstantPriceFunction, MockUniV2PriceFunction
    };

    // #[test]
    // #[available_gas(20000000)]
    // fn should_fully_use_alternative_if_better() {
    //     // Given
    //     let (exchange, _, _) = deploy_exchange();

    //     let beneficiary = contract_address_const::<0x12345>();

    //     let sell_token = deploy_mock_token(beneficiary, 10, 1);
    //     let sell_token_address = sell_token.contract_address;
    //     let sell_token_amount = u256 { low: 10, high: 0 };

    //     let buy_token = deploy_mock_token(beneficiary, 0, 2);
    //     let buy_token_address = buy_token.contract_address;
    //     let buy_token_min_amount = u256 { low: 9, high: 0 };
    //     let buy_token_amount = u256 { low: 9, high: 0 };

    //     let mut additional_swap_params = ArrayTrait::new();
    //     Serde::serialize(@MockPriceFunction::Constant(MockConstantPriceFunction { 
    //         price: 2 * 18446744073709551616
    //     }), ref additional_swap_params);

    //     let mut alternatives = ArrayTrait::new();
    //     alternatives
    //         .append(
    //             AlternativeSwap {
    //                 exchange_address: contract_address_const::<0x12>(),
    //                 percent: 20 * ROUTE_PERCENT_FACTOR,
    //                 minimum_price: 18446744073709551616,
    //                 additional_swap_params,
    //             },
    //         );

    //     let mut routes = ArrayTrait::new();
    //     routes
    //         .append(
    //             Route {
    //                 sell_token: sell_token_address,
    //                 buy_token: buy_token_address,
    //                 swap: RouteSwap::Branch(
    //                     BranchSwap {
    //                         principal: DirectSwap {
    //                             exchange_address: contract_address_const::<0x12>(),
    //                             percent: 100 * ROUTE_PERCENT_FACTOR,
    //                             additional_swap_params: ArrayTrait::new(),
    //                         },
    //                         alternatives,
    //                     },
    //                 ),
    //             },
    //         );

    //     set_contract_address(beneficiary);
    //     sell_token.approve(exchange.contract_address, sell_token_amount);

    //     // When
    //     let result = exchange
    //         .multi_route_swap(
    //             sell_token_address,
    //             sell_token_amount,
    //             buy_token_address,
    //             buy_token_amount,
    //             buy_token_min_amount,
    //             beneficiary,
    //             0,
    //             contract_address_const::<0x0>(),
    //             routes,
    //         );

    //     // Then
    //     assert(result == true, 'invalid result');

    //     // Verify that beneficiary receives tokens to
    //     let balance = buy_token.balanceOf(beneficiary);
    //     println!("{}", balance);
    //     assert(balance == 12_u256, 'Invalid beneficiary balance');
    // }

    #[test]
    #[available_gas(20000000)]
    fn should_properly_adjuste_alternative_amount() {
        // Given
        let (exchange, _, _) = deploy_exchange();

        let beneficiary = contract_address_const::<0x12345>();

        let sell_token = deploy_mock_token(beneficiary, 10, 1);
        let sell_token_address = sell_token.contract_address;
        let sell_token_amount = u256 { low: 10, high: 0 };

        let buy_token = deploy_mock_token(beneficiary, 0, 2);
        let buy_token_address = buy_token.contract_address;
        let buy_token_min_amount = u256 { low: 9, high: 0 };
        let buy_token_amount = u256 { low: 9, high: 0 };

        let mut additional_swap_params = ArrayTrait::new();
        // Start with an AMM where trading 5 unit gives a price of P = 1.8
        Serde::serialize(@MockPriceFunction::UniV2(MockUniV2PriceFunction { 
            reserve_a: 10,
            reserve_b: 30
        }), ref additional_swap_params);

        // Use alternative if we get a price of at least P = 2
        let mut alternatives = ArrayTrait::new();
        alternatives
            .append(
                AlternativeSwap {
                    exchange_address: contract_address_const::<0x12>(),
                    percent: 50 * ROUTE_PERCENT_FACTOR,
                    minimum_price: 2 * 18446744073709551616,
                    additional_swap_params,
                },
            );

        let mut additional_swap_params = ArrayTrait::new();
        // Start with an AMM where trading 5 unit gives a price of P = 1.8
        Serde::serialize(@MockPriceFunction::UniV2(MockUniV2PriceFunction { 
            reserve_a: 10,
            reserve_b: 40
        }), ref additional_swap_params);

        let mut routes = ArrayTrait::new();
        routes
            .append(
                Route {
                    sell_token: sell_token_address,
                    buy_token: buy_token_address,
                    swap: RouteSwap::Branch(
                        BranchSwap {
                            principal: DirectSwap {
                                exchange_address: contract_address_const::<0x12>(),
                                percent: 100 * ROUTE_PERCENT_FACTOR,
                                additional_swap_params,
                            },
                            alternatives,
                        },
                    ),
                },
            );

        set_contract_address(beneficiary);
        sell_token.approve(exchange.contract_address, sell_token_amount);

        // When
        let result = exchange
            .multi_route_swap(
                sell_token_address,
                sell_token_amount,
                buy_token_address,
                buy_token_amount,
                buy_token_min_amount,
                beneficiary,
                0,
                contract_address_const::<0x0>(),
                routes,
            );

        // Then
        assert(result == true, 'invalid result');

        // Verify that beneficiary receives tokens to
        let balance = buy_token.balanceOf(beneficiary);
        assert(balance == 22_u256, 'Invalid beneficiary balance');
    }

    // #[test]
    // #[available_gas(20000000)]
    // fn should_not_use_alternative_if_not_better() {
    //     // Given
    //     let (exchange, _, _) = deploy_exchange();

    //     let beneficiary = contract_address_const::<0x12345>();

    //     let sell_token = deploy_mock_token(beneficiary, 10, 1);
    //     let sell_token_address = sell_token.contract_address;
    //     let sell_token_amount = u256 { low: 10, high: 0 };

    //     let buy_token = deploy_mock_token(beneficiary, 0, 2);
    //     let buy_token_address = buy_token.contract_address;
    //     let buy_token_min_amount = u256 { low: 9, high: 0 };
    //     let buy_token_amount = u256 { low: 9, high: 0 };

    //     let mut additional_swap_params = ArrayTrait::new();
    //     additional_swap_params.append(9223372036854775808);

    //     let mut alternatives = ArrayTrait::new();
    //     alternatives
    //         .append(
    //             AlternativeSwap {
    //                 exchange_address: contract_address_const::<0x12>(),
    //                 percent: 20 * ROUTE_PERCENT_FACTOR,
    //                 minimum_price: 18446744073709551616,
    //                 additional_swap_params,
    //             },
    //         );

    //     let mut routes = ArrayTrait::new();
    //     routes
    //         .append(
    //             Route {
    //                 sell_token: sell_token_address,
    //                 buy_token: buy_token_address,
    //                 swap: RouteSwap::Branch(
    //                     BranchSwap {
    //                         principal: DirectSwap {
    //                             exchange_address: contract_address_const::<0x12>(),
    //                             percent: 100 * ROUTE_PERCENT_FACTOR,
    //                             additional_swap_params: ArrayTrait::new(),
    //                         },
    //                         alternatives,
    //                     },
    //                 ),
    //             },
    //         );

    //     set_contract_address(beneficiary);
    //     sell_token.approve(exchange.contract_address, sell_token_amount);

    //     // When
    //     let result = exchange
    //         .multi_route_swap(
    //             sell_token_address,
    //             sell_token_amount,
    //             buy_token_address,
    //             buy_token_amount,
    //             buy_token_min_amount,
    //             beneficiary,
    //             0,
    //             contract_address_const::<0x0>(),
    //             routes,
    //         );

    //     // Then
    //     assert(result == true, 'invalid result');

    //     // Verify that beneficiary receives tokens to
    //     let balance = buy_token.balanceOf(beneficiary);
    //     assert(balance == 10_u256, 'Invalid beneficiary balance');
    // }
}