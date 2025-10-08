use avnu::components::fee::{FeePolicy, IFeeDispatcherTrait, TokenFeeConfig};
use starknet::contract_address_const;
use starknet::testing::set_contract_address;
use crate::components::mocks::fee_mock::IFeeMockDispatcherTrait;
use super::helper::{deploy_fee, deploy_fee_with_address, deploy_fee_with_defaults, deploy_mock_token, get_common_actors};

fn a_token_fee_config(weight: u32) -> TokenFeeConfig {
    TokenFeeConfig { weight }
}


mod GetSetFeesRecipient {
    use super::{IFeeDispatcherTrait, contract_address_const, deploy_fee, set_contract_address};

    #[test]
    fn should_set_fees_recipient() {
        // Given
        let fee = deploy_fee();
        set_contract_address(contract_address_const::<'OWNER'>());
        let fees_recipient = contract_address_const::<'NEWFEESRECIPIENT'>();

        // Check pre-action state
        assert(fee.get_fees_recipient() == contract_address_const::<'FEES_RECIPIENT'>(), 'invalid fees recipient');

        // When
        let result = fee.set_fees_recipient(fees_recipient);

        // Then
        assert(result == true, 'invalid result');
        assert(fee.get_fees_recipient() == fees_recipient, 'invalid fees recipient');
    }

    #[test]
    #[should_panic(expected: ('Caller is not the owner', 'ENTRYPOINT_FAILED'))]
    fn set_fees_recipient_should_fail_for_unauthorized_access() {
        let fee = deploy_fee();
        set_contract_address(contract_address_const::<'NOT_OWNER'>());
        fee.set_fees_recipient(contract_address_const::<'MALICIOUS_ACTOR'>());
    }
}
mod GetSetFeeBps {
    use super::{IFeeDispatcherTrait, contract_address_const, deploy_fee, set_contract_address};

    #[test]
    fn should_set_fees_bps_0() {
        // Given
        let fee = deploy_fee();
        set_contract_address(contract_address_const::<'OWNER'>());

        // When
        let result = fee.set_fees_bps_0(10);

        // Then
        assert(result == true, 'invalid result');
        assert(fee.get_fees_bps_0() == 10, 'invalid fee bps 0');
    }

    #[test]
    fn should_set_fees_bps_1() {
        // Given
        let fee = deploy_fee();
        set_contract_address(contract_address_const::<'OWNER'>());

        // When
        let result = fee.set_fees_bps_1(10);

        // Then
        assert(result == true, 'invalid result');
        assert(fee.get_fees_bps_0() == 0, 'invalid fee bps 0');
        assert(fee.get_fees_bps_1() == 10, 'invalid fee bps 1');
    }

    #[test]
    fn should_set_swap_exact_fees_bps() {
        // Given
        let fee = deploy_fee();
        set_contract_address(contract_address_const::<'OWNER'>());

        // Check pre-action state
        assert(fee.get_swap_exact_token_to_fees_bps() == 30, 'invalid fee bps 0');
        // When
        let result = fee.set_swap_exact_token_to_fees_bps(10);

        // Then
        assert(result == true, 'invalid result');
        assert(fee.get_swap_exact_token_to_fees_bps() == 10, 'invalid fee bps 0');
    }

    #[test]
    #[should_panic(expected: ('Caller is not the owner', 'ENTRYPOINT_FAILED'))]
    fn set_fees_bps_0_should_fail_for_unathorized_access() {
        // Given
        let fee = deploy_fee();
        set_contract_address(contract_address_const::<'NOT_OWNER'>());

        // When & Then
        fee.set_fees_bps_0(10);
    }

    #[test]
    #[should_panic(expected: ('Caller is not the owner', 'ENTRYPOINT_FAILED'))]
    fn set_fees_bps_1_should_fail_for_unathorized_access() {
        // Given
        let fee = deploy_fee();
        set_contract_address(contract_address_const::<'NOT_OWNER'>());

        // When & Then
        fee.set_fees_bps_1(10);
    }

    #[test]
    #[should_panic(expected: ('Caller is not the owner', 'ENTRYPOINT_FAILED'))]
    fn set_swap_exact_fees_bps_should_fail_for_unathorized_access() {
        // Given
        let fee = deploy_fee();
        set_contract_address(contract_address_const::<'NOT_OWNER'>());

        // When & Then
        fee.set_swap_exact_token_to_fees_bps(10);
    }

    #[test]
    #[should_panic(expected: ('Fees are too high', 'ENTRYPOINT_FAILED'))]
    fn set_fees_bps_0_should_fail_for_too_high_bps() {
        // Given
        let fee = deploy_fee();
        set_contract_address(contract_address_const::<'OWNER'>());

        // When & Then
        fee.set_fees_bps_0(101);
    }

    #[test]
    #[should_panic(expected: ('Fees are too high', 'ENTRYPOINT_FAILED'))]
    fn set_fees_bps_1_should_fail_for_too_high_bps() {
        // Given
        let fee = deploy_fee();
        set_contract_address(contract_address_const::<'OWNER'>());

        // When & Then
        fee.set_fees_bps_1(101);
    }

    #[test]
    #[should_panic(expected: ('Fees are too high', 'ENTRYPOINT_FAILED'))]
    fn set_swap_exact_token_fees_bps_should_fail_for_too_high_bps() {
        // Given
        let fee = deploy_fee();
        set_contract_address(contract_address_const::<'OWNER'>());

        // When & Then
        fee.set_swap_exact_token_to_fees_bps(101);
    }
}


mod GetTokenFeeConfig {
    use super::{IFeeDispatcherTrait, contract_address_const, deploy_fee};

    #[test]
    fn should_return_default_config_value_when_token_config_not_stored() {
        // Given
        let fee = deploy_fee();
        let token = contract_address_const::<'TOKEN_1'>();

        // When
        let result = fee.get_token_fee_config(token);

        // Then
        assert(result.weight == 0, 'invalid weight');
    }
}

mod SetTokenFeeConfig {
    use super::{IFeeDispatcherTrait, TokenFeeConfig, a_token_fee_config, contract_address_const, deploy_fee, set_contract_address};

    #[test]
    fn should_set_token_fee_config() {
        // Given
        let fee = deploy_fee();
        let config = TokenFeeConfig { weight: 10 };
        set_contract_address(contract_address_const::<'OWNER'>());
        let token = contract_address_const::<'TOKEN_1'>();

        // When
        let result = fee.set_token_fee_config(token, config);

        // Then
        assert(result == true, 'invalid result');
        let result = fee.get_token_fee_config(token);
        assert(result.weight == 10, 'invalid weight');
    }

    #[test]
    #[should_panic(expected: ('Caller is not the owner', 'ENTRYPOINT_FAILED'))]
    fn should_fail_when_caller_is_not_the_owner() {
        // Given
        let fee = deploy_fee();
        let config = a_token_fee_config(10);
        let token = contract_address_const::<'TOKEN_1'>();
        set_contract_address(contract_address_const::<'NOT_OWNER'>());

        // When & Then
        fee.set_token_fee_config(token, config);
    }
}

mod IsIntegratorWhitelisted {
    use super::{IFeeDispatcherTrait, contract_address_const, deploy_fee};

    #[test]
    fn should_return_false_when_not_whitelisted() {
        // Given
        let fee = deploy_fee();
        let integrator = contract_address_const::<'INTEGRATOR'>();

        // When
        let result = fee.is_integrator_whitelisted(integrator);

        // Then
        assert(result == false, 'invalid result');
    }
}

mod SetWhitelistedIntegrator {
    use super::{IFeeDispatcherTrait, contract_address_const, deploy_fee, set_contract_address};

    #[test]
    fn should_whitelist_integrator() {
        // Given
        let fee = deploy_fee();
        set_contract_address(contract_address_const::<'OWNER'>());
        let integrator = contract_address_const::<'INTEGRATOR'>();

        // Check pre-action state
        let result = fee.is_integrator_whitelisted(integrator);
        assert(result == false, 'invalid status');

        // When
        let result = fee.set_whitelisted_integrator(integrator, true);

        // Then
        assert(result == true, 'invalid result');
        let result = fee.is_integrator_whitelisted(integrator);
        assert(result == true, 'invalid status');
    }

    #[test]
    #[should_panic(expected: ('Caller is not the owner', 'ENTRYPOINT_FAILED'))]
    fn should_fail_when_caller_is_not_the_owner() {
        // Given
        let fee = deploy_fee();
        let integrator = contract_address_const::<'INTEGRATOR'>();
        set_contract_address(contract_address_const::<'NOT_OWNER'>());

        // When & Then
        fee.set_whitelisted_integrator(integrator, true);
    }
}

mod GetFees {
    use super::{
        FeePolicy, IFeeDispatcherTrait, IFeeMockDispatcherTrait, TokenFeeConfig, contract_address_const, deploy_fee_with_defaults, get_common_actors,
        set_contract_address,
    };

    // FeeOnBuy, route len = 1, integrator not whitelisted
    #[test]
    fn fee_on_buy_simple_no_integrator() {
        // Given
        let (_fee, fee_mock) = deploy_fee_with_defaults();
        let (sell_token, buy_token, integrator_recipient) = get_common_actors();

        // When
        let (policy, fees_bps) = fee_mock.get_fees(sell_token, buy_token, integrator_recipient, 300, 1);

        // Then
        assert(policy == FeePolicy::FeeOnBuy, 'invalid policy');
        assert(fees_bps == 50, 'invalid fees bps');
    }

    // FeeOnSell, route len = 1, integrator not whitelisted
    #[test]
    fn fee_on_sell_simple_no_integrator() {
        // Given
        let (fee, fee_mock) = deploy_fee_with_defaults();
        let (sell_token, buy_token, integrator_recipient) = get_common_actors();
        let config = TokenFeeConfig { weight: 10 };
        set_contract_address(contract_address_const::<'OWNER'>());
        fee.set_token_fee_config(sell_token, config);

        // When
        let (policy, fees_bps) = fee_mock.get_fees(sell_token, buy_token, integrator_recipient, 300, 1);

        // Then
        assert(policy == FeePolicy::FeeOnSell, 'invalid policy');
        assert(fees_bps == 50, 'invalid fees bps');
    }

    // FeeOnBuy, route len > 1, integrator not whitelisted
    #[test]
    fn fee_on_buy_complex_no_integrator() {
        // Given
        let (fee, fee_mock) = deploy_fee_with_defaults();
        let (sell_token, buy_token, integrator_recipient) = get_common_actors();
        let config = TokenFeeConfig { weight: 10 };
        set_contract_address(contract_address_const::<'OWNER'>());
        fee.set_token_fee_config(buy_token, config);

        // When
        let (policy, fees_bps) = fee_mock.get_fees(sell_token, buy_token, integrator_recipient, 0, 2);

        // Then
        assert(policy == FeePolicy::FeeOnBuy, 'invalid policy');
        assert(fees_bps == 100, 'invalid fees bps');
    }

    // FeeOnSell, route len > 1, integrator not whitelisted
    #[test]
    fn fee_on_sell_complex_no_integrator() {
        // Given
        let (fee, fee_mock) = deploy_fee_with_defaults();
        let (sell_token, buy_token, integrator_recipient) = get_common_actors();
        let config = TokenFeeConfig { weight: 10 };
        set_contract_address(contract_address_const::<'OWNER'>());
        fee.set_token_fee_config(sell_token, config);

        // When
        let (policy, fees_bps) = fee_mock.get_fees(sell_token, buy_token, integrator_recipient, 300, 2);

        // Then
        assert(policy == FeePolicy::FeeOnSell, 'invalid policy');
        assert(fees_bps == 100, 'invalid fees bps');
    }

    // FeeOnBuy, route len = 1, integrator whitelisted with integrator fee < fees_bps
    #[test]
    fn fee_on_buy_simple_integrator_fees_less() {
        // Given
        let (fee, fee_mock) = deploy_fee_with_defaults();
        let (sell_token, buy_token, integrator_recipient) = get_common_actors();
        set_contract_address(contract_address_const::<'OWNER'>());
        fee.set_whitelisted_integrator(integrator_recipient, true);
        // When
        let (policy, fees_bps) = fee_mock.get_fees(sell_token, buy_token, integrator_recipient, 40, 1);

        // Then
        assert(policy == FeePolicy::FeeOnBuy, 'invalid policy');
        assert(fees_bps == 50, 'invalid fees bps');
    }

    // FeeOnSell, route len = 1, integrator whitelisted with integrator fee < fees_bps
    #[test]
    fn fee_on_sell_simple_integrator_fees_less() {
        // Given
        let (fee, fee_mock) = deploy_fee_with_defaults();
        let (sell_token, buy_token, integrator_recipient) = get_common_actors();
        let config = TokenFeeConfig { weight: 10 };
        set_contract_address(contract_address_const::<'OWNER'>());
        fee.set_whitelisted_integrator(integrator_recipient, true);
        fee.set_token_fee_config(sell_token, config);

        // When
        let (policy, fees_bps) = fee_mock.get_fees(sell_token, buy_token, integrator_recipient, 40, 1);

        // Then
        assert(policy == FeePolicy::FeeOnSell, 'invalid policy');
        assert(fees_bps == 50, 'invalid fees bps');
    }

    // FeeOnBuy, route len > 1, integrator whitelisted with integrator fee < fees_bps
    #[test]
    fn fee_on_buy_complex_integrator_fees_less() {
        // Given
        let (fee, fee_mock) = deploy_fee_with_defaults();
        let (sell_token, buy_token, integrator_recipient) = get_common_actors();
        let config = TokenFeeConfig { weight: 10 };
        set_contract_address(contract_address_const::<'OWNER'>());
        fee.set_whitelisted_integrator(integrator_recipient, true);
        fee.set_token_fee_config(buy_token, config);

        // When
        let (policy, fees_bps) = fee_mock.get_fees(sell_token, buy_token, integrator_recipient, 99, 2);

        // Then
        assert(policy == FeePolicy::FeeOnBuy, 'invalid policy');
        assert(fees_bps == 100, 'invalid fees bps');
    }

    // FeeOnSell, route len > 1, integrator whitelisted with integrator fee < fees_bps
    #[test]
    fn fee_on_sell_complex_integrator_fees_less() {
        // Given
        let (fee, fee_mock) = deploy_fee_with_defaults();
        let (sell_token, buy_token, integrator_recipient) = get_common_actors();
        let config = TokenFeeConfig { weight: 10 };
        set_contract_address(contract_address_const::<'OWNER'>());
        fee.set_whitelisted_integrator(integrator_recipient, true);
        fee.set_token_fee_config(sell_token, config);

        // When
        let (policy, fees_bps) = fee_mock.get_fees(sell_token, buy_token, integrator_recipient, 99, 2);

        // Then
        assert(policy == FeePolicy::FeeOnSell, 'invalid policy');
        assert(fees_bps == 100, 'invalid fees bps');
    }

    // FeeOnBuy, route len = 1, integrator whitelisted with integrator fee = fees_bps
    #[test]
    fn fee_on_buy_simple_integrator_fees_more() {
        // Given
        let (fee, fee_mock) = deploy_fee_with_defaults();
        let (sell_token, buy_token, integrator_recipient) = get_common_actors();
        set_contract_address(contract_address_const::<'OWNER'>());
        fee.set_whitelisted_integrator(integrator_recipient, true);
        // When
        let (policy, fees_bps) = fee_mock.get_fees(sell_token, buy_token, integrator_recipient, 50, 1);

        // Then
        assert(policy == FeePolicy::FeeOnBuy, 'invalid policy');
        assert(fees_bps == 0, 'invalid fees bps');
    }

    // FeeOnSell, route len > 1, integrator whitelisted with integrator fee > fees_bps
    #[test]
    fn fee_on_sell_complex_integrator_fees_more() {
        // Given
        let (fee, fee_mock) = deploy_fee_with_defaults();
        let (sell_token, buy_token, integrator_recipient) = get_common_actors();
        let config = TokenFeeConfig { weight: 10 };
        set_contract_address(contract_address_const::<'OWNER'>());
        fee.set_whitelisted_integrator(integrator_recipient, true);
        fee.set_token_fee_config(sell_token, config);

        // When
        let (policy, fees_bps) = fee_mock.get_fees(sell_token, buy_token, integrator_recipient, 300, 2);

        // Then
        assert(policy == FeePolicy::FeeOnSell, 'invalid policy');
        assert(fees_bps == 0, 'invalid fees bps');
    }
}

mod CollectFees {
    use avnu_lib::interfaces::erc20::IERC20DispatcherTrait;
    use super::{IFeeMockDispatcherTrait, contract_address_const, deploy_fee_with_address, deploy_mock_token, get_common_actors};

    fn collect_fee_exchange_and_integrator() {
        // Given
        let (_fee, fee_mock, fee_address) = deploy_fee_with_address();
        let (_sell_token, _buy_token, integrator_recipient) = get_common_actors();
        let amount: felt252 = 10000;
        let token = deploy_mock_token(fee_address, amount, 1);
        let amount_u256 = 10000_u256;
        let fee_recipient = contract_address_const::<'FEE_RECIPIENT'>();

        // When
        let remaining_amount = fee_mock.collect_fees(token, amount_u256, 10, integrator_recipient, 30);

        // Then
        let expected_remaining_amount = amount_u256 - 30_u256 - 10_u256;
        assert(token.balanceOf(integrator_recipient) == 30_u256, 'invalid token balance');
        assert(token.balanceOf(fee_recipient) == 10_u256, 'invalid token balance');
        assert(remaining_amount == expected_remaining_amount, 'invalid remaining amount');
    }

    fn collect_fee_nil_exchange_and_integrator() {
        // Given
        let (_fee, fee_mock, fee_address) = deploy_fee_with_address();
        let (_sell_token, _buy_token, integrator_recipient) = get_common_actors();
        let amount: felt252 = 10000;
        let token = deploy_mock_token(fee_address, amount, 1);
        let amount_u256 = 10000_u256;
        let fee_recipient = contract_address_const::<'FEE_RECIPIENT'>();

        // When
        let remaining_amount = fee_mock.collect_fees(token, amount_u256, 0, integrator_recipient, 30);

        // Then
        let expected_remaining_amount = amount_u256 - 30_u256 - 0_u256;
        assert(token.balanceOf(integrator_recipient) == 30_u256, 'invalid token balance');
        assert(token.balanceOf(fee_recipient) == 0_u256, 'invalid token balance');
        assert(remaining_amount == expected_remaining_amount, 'invalid remaining amount');
    }

    fn collect_fee_exchange_and_nil_integrator() {
        // Given
        let (_fee, fee_mock, fee_address) = deploy_fee_with_address();
        let (_sell_token, _buy_token, integrator_recipient) = get_common_actors();
        let amount: felt252 = 10000;
        let token = deploy_mock_token(fee_address, amount, 1);
        let amount_u256 = 10000_u256;
        let fee_recipient = contract_address_const::<'FEE_RECIPIENT'>();

        // When
        let remaining_amount = fee_mock.collect_fees(token, amount_u256, 10, integrator_recipient, 0);

        // Then
        let expected_remaining_amount = amount_u256 - 0_u256 - 10_u256;
        assert(token.balanceOf(integrator_recipient) == 0_u256, 'invalid token balance');
        assert(token.balanceOf(fee_recipient) == 10_u256, 'invalid token balance');
        assert(remaining_amount == expected_remaining_amount, 'invalid remaining amount');
    }

    #[test]
    #[should_panic(expected: ('Integrator fees are too high', 'ENTRYPOINT_FAILED'))]
    fn should_throw_collect_fee_exchange_and_high_integrator_fees() {
        // Given
        let (_fee, fee_mock, fee_address) = deploy_fee_with_address();
        let (_sell_token, _buy_token, integrator_recipient) = get_common_actors();
        let amount: felt252 = 10000;
        let token = deploy_mock_token(fee_address, amount, 1);
        let amount_u256 = 10000_u256;
        let fee_recipient = contract_address_const::<'FEE_RECIPIENT'>();

        // When
        let remaining_amount = fee_mock.collect_fees(token, amount_u256, 10, integrator_recipient, 501);

        // Then
        let expected_remaining_amount = amount_u256 - 501_u256 - 10_u256;
        assert(token.balanceOf(integrator_recipient) == 501_u256, 'invalid token balance');
        assert(token.balanceOf(fee_recipient) == 10_u256, 'invalid token balance');
        assert(remaining_amount == expected_remaining_amount, 'invalid remaining amount');
    }
}

