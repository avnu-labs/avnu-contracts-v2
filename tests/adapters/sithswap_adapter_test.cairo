mod Swap {
    use avnu::adapters::ISwapAdapterDispatcherTrait;
    use crate::helper::{deploy_mock_sithswap, deploy_mock_token, deploy_sithswap_adapter};
    use starknet::{contract_address_const, get_caller_address};

    #[test]
    fn should_call_sithswap() {
        // Given
        let adapter = deploy_sithswap_adapter();
        let exchange = deploy_mock_sithswap();
        let sell_token = deploy_mock_token(get_caller_address(), 1, 1);
        let buy_token = deploy_mock_token(get_caller_address(), 0, 2);
        let mut additional_params = ArrayTrait::new();
        additional_params.append(0x1);
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
        let adapter = deploy_sithswap_adapter();
        let exchange = deploy_mock_sithswap();
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
