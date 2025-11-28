mod Swap {
    use avnu::adapters::ISwapAdapterDispatcherTrait;
    #[feature("deprecated-starknet-consts")]
    use starknet::{contract_address_const, get_caller_address};
    use crate::helper::{deploy_mock_myswap, deploy_mock_token, deploy_myswap_adapter};

    #[test]
    fn should_call_myswap() {
        // Given
        let adapter = deploy_myswap_adapter();
        let exchange = deploy_mock_myswap();
        let sell_token = deploy_mock_token(get_caller_address(), 1, 1);
        let buy_token = deploy_mock_token(get_caller_address(), 0, 2);
        let mut additional_params = ArrayTrait::new();
        additional_params.append(0x9);
        let to = contract_address_const::<0x4>();

        // When
        adapter
            .swap(
                exchange.contract_address,
                sell_token.contract_address,
                u256 { low: 1, high: 0 },
                buy_token.contract_address,
                u256 { low: 2, high: 0 },
                to,
                additional_params,
            );
        // Then
    // TODO: verify calls
    }

    #[test]
    #[should_panic(expected: ('Invalid swap params', 'ENTRYPOINT_FAILED'))]
    fn should_fail_when_invalid_additional_swap_params() {
        // Given
        let adapter = deploy_myswap_adapter();
        let exchange = deploy_mock_myswap();
        let sell_token = deploy_mock_token(get_caller_address(), 1, 1);
        let buy_token = deploy_mock_token(get_caller_address(), 0, 2);
        let mut additional_params = ArrayTrait::new();
        let to = contract_address_const::<0x4>();

        // When & Then
        adapter
            .swap(
                exchange.contract_address,
                sell_token.contract_address,
                u256 { low: 1, high: 0 },
                buy_token.contract_address,
                u256 { low: 2, high: 0 },
                to,
                additional_params,
            );
    }
}
