mod Swap {
    use avnu::adapters::ISwapAdapterDispatcherTrait;
    use avnu_tests::helper::{deploy_mock_jediswap, deploy_mock_token, deploy_jediswap_adapter};
    use starknet::{contract_address_const, get_caller_address};

    #[test]
    #[available_gas(2000000)]
    fn should_call_jediswap() {
        // Given
        let adapter = deploy_jediswap_adapter();
        let exchange = deploy_mock_jediswap();
        let token_from = deploy_mock_token(get_caller_address(), 1, 1);
        let token_to = deploy_mock_token(get_caller_address(), 0, 2);
        let additional_params = ArrayTrait::new();
        let to = contract_address_const::<0x4>();

        // When
        adapter
            .swap(
                exchange.contract_address,
                token_from.contract_address,
                u256 { low: 1, high: 0 },
                token_to.contract_address,
                u256 { low: 2, high: 0 },
                to,
                additional_params,
            );
    // Then
    // TODO: verify calls
    }

    #[test]
    #[available_gas(2000000)]
    #[should_panic(expected: ('Invalid swap params', 'ENTRYPOINT_FAILED'))]
    fn should_fail_when_invalid_additional_swap_params() {
        // Given
        let adapter = deploy_jediswap_adapter();
        let exchange = deploy_mock_jediswap();
        let token_from = deploy_mock_token(get_caller_address(), 1, 1);
        let token_to = deploy_mock_token(get_caller_address(), 0, 2);
        let mut additional_params = ArrayTrait::new();
        additional_params.append(0x1);
        let to = contract_address_const::<0x4>();

        // When & Then
        adapter
            .swap(
                exchange.contract_address,
                token_from.contract_address,
                u256 { low: 1, high: 0 },
                token_to.contract_address,
                u256 { low: 2, high: 0 },
                to,
                additional_params,
            );
    }
}
