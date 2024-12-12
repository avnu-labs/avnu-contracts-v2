use avnu::components::fee::{FeePolicy, TokenFeeConfig};
use avnu::components::fee::{IFeeDispatcherTrait};
use crate::components::mocks::fee_mock::{IFeeMockDispatcher, IFeeMockDispatcherTrait};
use starknet::contract_address_const;
use starknet::testing::set_contract_address;
use super::helper::deploy_fee;

fn a_token_fee_config(weight: u32) -> TokenFeeConfig {
    TokenFeeConfig { weight, fee_on_buy: Option::None, fee_on_sell: Option::None }
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
        assert(result.fee_on_buy == Option::None, 'invalid fee_on_buy');
        assert(result.fee_on_sell == Option::None, 'invalid fee_on_sell');
    }
}

mod SetTokenFeeConfig {
    use super::{IFeeDispatcherTrait, TokenFeeConfig, a_token_fee_config, contract_address_const, deploy_fee, set_contract_address};

    #[test]
    fn should_set_token_fee_config() {
        // Given
        let fee = deploy_fee();
        let config = TokenFeeConfig { weight: 10, fee_on_buy: Option::Some(5), fee_on_sell: Option::None };
        set_contract_address(contract_address_const::<'OWNER'>());
        let token = contract_address_const::<'TOKEN_1'>();

        // When
        let result = fee.set_token_fee_config(token, config);

        // Then
        assert(result == true, 'invalid result');
        let result = fee.get_token_fee_config(token);
        assert(result.weight == 10, 'invalid weight');
        assert(result.fee_on_buy == Option::Some(5), 'invalid fee_on_buy');
        assert(result.fee_on_sell == Option::None, 'invalid fee_on_sell');
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

mod GetPairSpecificFees {
    use super::{IFeeDispatcherTrait, contract_address_const, deploy_fee};

    #[test]
    fn should_return_None_when_pair_not_stored() {
        // Given
        let fee = deploy_fee();
        let token_a = contract_address_const::<'TOKEN_1'>();
        let token_b = contract_address_const::<'TOKEN_2'>();

        // When
        let result = fee.get_pair_specific_fees(token_a, token_b);

        // Then
        assert(result == Option::None, 'invalid result');
    }
}

mod SetPairSpecificFees {
    use super::{IFeeDispatcherTrait, contract_address_const, deploy_fee, set_contract_address};

    #[test]
    fn should_set_pair_specific_fees() {
        // Given
        let fee = deploy_fee();
        set_contract_address(contract_address_const::<'OWNER'>());
        let token_a = contract_address_const::<'TOKEN_1'>();
        let token_b = contract_address_const::<'TOKEN_2'>();

        // When
        let result = fee.set_pair_specific_fees(token_a, token_b, Option::Some(0));

        // Then
        assert(result == true, 'invalid result');
        let result = fee.get_pair_specific_fees(token_a, token_b);
        assert(result == Option::Some(0), 'invalid weight');
    }

    #[test]
    fn should_set_pair_specific_fees_when_reversed_tokens() {
        // Given
        let fee = deploy_fee();
        set_contract_address(contract_address_const::<'OWNER'>());
        let token_a = contract_address_const::<'TOKEN_1'>();
        let token_b = contract_address_const::<'TOKEN_2'>();

        // When
        let result = fee.set_pair_specific_fees(token_b, token_a, Option::Some(0));

        // Then
        assert(result == true, 'invalid result');
        let result = fee.get_pair_specific_fees(token_a, token_b);
        assert(result == Option::Some(0), 'invalid weight');
    }

    #[test]
    #[should_panic(expected: ('Caller is not the owner', 'ENTRYPOINT_FAILED'))]
    fn should_fail_when_caller_is_not_the_owner() {
        // Given
        let fee = deploy_fee();
        let token_a = contract_address_const::<'TOKEN_1'>();
        let token_b = contract_address_const::<'TOKEN_2'>();
        set_contract_address(contract_address_const::<'NOT_OWNER'>());

        // When & Then
        fee.set_pair_specific_fees(token_a, token_b, Option::Some(0));
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
    fn should_set_pair_specific_fees() {
        // Given
        let fee = deploy_fee();
        set_contract_address(contract_address_const::<'OWNER'>());
        let integrator = contract_address_const::<'INTEGRATOR'>();

        // When
        let result = fee.set_whitelisted_integrator(integrator, true);

        // Then
        assert(result == true, 'invalid result');
        let result = fee.is_integrator_whitelisted(integrator);
        assert(result == true, 'invalid weight');
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
        FeePolicy, IFeeDispatcherTrait, IFeeMockDispatcher, IFeeMockDispatcherTrait, TokenFeeConfig, a_token_fee_config, contract_address_const,
        deploy_fee, set_contract_address,
    };

    #[test]
    fn should_return_fee_on_buy_and_default_fee_amount_when_both_token_dont_have_config_and_no_integrator() {
        // Given
        let fee = deploy_fee();
        let fee = IFeeMockDispatcher { contract_address: fee.contract_address };
        let integrator = contract_address_const::<0>();
        let integrator_bps = 0;
        let token1 = contract_address_const::<'TOKEN_1'>();
        let token2 = contract_address_const::<'TOKEN_2'>();

        // When
        let (result_policy, result_fees) = fee.get_fees(token1, token2, integrator, integrator_bps);

        // Then
        assert(result_policy == FeePolicy::FeeOnBuy, 'invalid fee policy');
        assert(result_fees == 10, 'invalid fee bps');
    }

    #[test]
    fn should_return_fee_on_buy_and_default_fee_amount_when_buy_token_weigh_is_higher_and_no_integrator() {
        // Given
        let fee = deploy_fee();
        let fee_mock = IFeeMockDispatcher { contract_address: fee.contract_address };
        let integrator = contract_address_const::<0>();
        let integrator_bps = 0;
        let token1 = contract_address_const::<'TOKEN_1'>();
        let token2 = contract_address_const::<'TOKEN_2'>();
        set_contract_address(contract_address_const::<'OWNER'>());
        fee.set_token_fee_config(token1, a_token_fee_config(10));
        fee.set_token_fee_config(token2, a_token_fee_config(20));
        set_contract_address(contract_address_const::<'NOT_OWNER'>());

        // When
        let (result_policy, result_fees) = fee_mock.get_fees(token1, token2, integrator, integrator_bps);

        // Then
        assert(result_policy == FeePolicy::FeeOnBuy, 'invalid fee policy');
        assert(result_fees == 10, 'invalid fee bps');
    }

    #[test]
    fn should_return_fee_on_sell_and_default_fee_amount_when_sell_token_weigh_is_higher_and_no_integrator() {
        // Given
        let fee = deploy_fee();
        let fee_mock = IFeeMockDispatcher { contract_address: fee.contract_address };
        let integrator = contract_address_const::<0>();
        let integrator_bps = 0;
        let token1 = contract_address_const::<'TOKEN_1'>();
        let token2 = contract_address_const::<'TOKEN_2'>();
        set_contract_address(contract_address_const::<'OWNER'>());
        fee.set_token_fee_config(token1, a_token_fee_config(500));
        fee.set_token_fee_config(token2, a_token_fee_config(20));
        set_contract_address(contract_address_const::<'NOT_OWNER'>());

        // When
        let (result_policy, result_fees) = fee_mock.get_fees(token1, token2, integrator, integrator_bps);

        // Then
        assert(result_policy == FeePolicy::FeeOnSell, 'invalid fee policy');
        assert(result_fees == 10, 'invalid fee bps');
    }

    #[test]
    fn should_return_fee_on_sell_and_pair_specific_fees_when_sell_token_weigh_is_higher_no_integrator_and_pair_exists() {
        // Given
        let fee = deploy_fee();
        let fee_mock = IFeeMockDispatcher { contract_address: fee.contract_address };
        let integrator = contract_address_const::<0>();
        let integrator_bps = 0;
        let token1 = contract_address_const::<'TOKEN_1'>();
        let token2 = contract_address_const::<'TOKEN_2'>();
        set_contract_address(contract_address_const::<'OWNER'>());
        fee.set_pair_specific_fees(token1, token2, Option::Some(0));
        fee.set_token_fee_config(token1, a_token_fee_config(500));
        fee.set_token_fee_config(token2, a_token_fee_config(20));
        set_contract_address(contract_address_const::<'NOT_OWNER'>());

        // When
        let (result_policy, result_fees) = fee_mock.get_fees(token1, token2, integrator, integrator_bps);

        // Then
        assert(result_policy == FeePolicy::FeeOnSell, 'invalid fee policy');
        assert(result_fees == 0, 'invalid fee bps');
    }

    #[test]
    fn should_return_fee_on_sell_and_buy_token_specific_fee_when_lowest() {
        // Given
        let fee = deploy_fee();
        let fee_mock = IFeeMockDispatcher { contract_address: fee.contract_address };
        let integrator = contract_address_const::<0>();
        let integrator_bps = 0;
        let token1 = contract_address_const::<'TOKEN_1'>();
        let token2 = contract_address_const::<'TOKEN_2'>();
        set_contract_address(contract_address_const::<'OWNER'>());
        fee.set_token_fee_config(token1, TokenFeeConfig { weight: 500, fee_on_buy: Option::Some(5), fee_on_sell: Option::Some(5) });
        fee.set_token_fee_config(token2, TokenFeeConfig { weight: 20, fee_on_buy: Option::Some(2), fee_on_sell: Option::Some(7) });
        set_contract_address(contract_address_const::<'NOT_OWNER'>());

        // When
        let (result_policy, result_fees) = fee_mock.get_fees(token1, token2, integrator, integrator_bps);

        // Then
        assert(result_policy == FeePolicy::FeeOnSell, 'invalid fee policy');
        assert(result_fees == 2, 'invalid fee bps');
    }

    #[test]
    fn should_return_fee_on_sell_and_sell_token_specific_fee_when_lowest() {
        // Given
        let fee = deploy_fee();
        let fee_mock = IFeeMockDispatcher { contract_address: fee.contract_address };
        let integrator = contract_address_const::<0>();
        let integrator_bps = 0;
        let token1 = contract_address_const::<'TOKEN_1'>();
        let token2 = contract_address_const::<'TOKEN_2'>();
        set_contract_address(contract_address_const::<'OWNER'>());
        fee.set_token_fee_config(token1, TokenFeeConfig { weight: 500, fee_on_buy: Option::Some(5), fee_on_sell: Option::Some(5) });
        fee.set_token_fee_config(token2, TokenFeeConfig { weight: 20, fee_on_buy: Option::Some(7), fee_on_sell: Option::None });
        set_contract_address(contract_address_const::<'NOT_OWNER'>());

        // When
        let (result_policy, result_fees) = fee_mock.get_fees(token1, token2, integrator, integrator_bps);

        // Then
        assert(result_policy == FeePolicy::FeeOnSell, 'invalid fee policy');
        assert(result_fees == 5, 'invalid fee bps');
    }

    #[test]
    fn should_return_fee_on_buy_and_our_fees_when_integrators_is_not_whitelisted() {
        // Given
        let fee = deploy_fee();
        let fee_mock = IFeeMockDispatcher { contract_address: fee.contract_address };
        let integrator = contract_address_const::<'INTEGRATOR'>();
        let integrator_bps = 50;
        let token1 = contract_address_const::<'TOKEN_1'>();
        let token2 = contract_address_const::<'TOKEN_2'>();
        set_contract_address(contract_address_const::<'OWNER'>());
        set_contract_address(contract_address_const::<'NOT_OWNER'>());

        // When
        let (result_policy, result_fees) = fee_mock.get_fees(token1, token2, integrator, integrator_bps);

        // Then
        assert(result_policy == FeePolicy::FeeOnBuy, 'invalid fee policy');
        assert(result_fees == 10, 'invalid fee bps');
    }

    #[test]
    fn should_return_fee_on_buy_and_our_fees_when_integrator_is_whitelisted_but_fees_lower_than_ours() {
        // Given
        let fee = deploy_fee();
        let fee_mock = IFeeMockDispatcher { contract_address: fee.contract_address };
        let integrator = contract_address_const::<'INTEGRATOR'>();
        let integrator_bps = 1;
        let token1 = contract_address_const::<'TOKEN_1'>();
        let token2 = contract_address_const::<'TOKEN_2'>();
        set_contract_address(contract_address_const::<'OWNER'>());
        fee.set_whitelisted_integrator(integrator, true);
        set_contract_address(contract_address_const::<'NOT_OWNER'>());

        // When
        let (result_policy, result_fees) = fee_mock.get_fees(token1, token2, integrator, integrator_bps);

        // Then
        assert(result_policy == FeePolicy::FeeOnBuy, 'invalid fee policy');
        assert(result_fees == 10, 'invalid fee bps');
    }

    #[test]
    fn should_return_fee_on_buy_and_0_fees_when_integrator_is_whitelisted_and_fees_higher_than_ours() {
        // Given
        let fee = deploy_fee();
        let fee_mock = IFeeMockDispatcher { contract_address: fee.contract_address };
        let integrator = contract_address_const::<'INTEGRATOR'>();
        let integrator_bps = 50;
        let token1 = contract_address_const::<'TOKEN_1'>();
        let token2 = contract_address_const::<'TOKEN_2'>();
        set_contract_address(contract_address_const::<'OWNER'>());
        fee.set_whitelisted_integrator(integrator, true);
        set_contract_address(contract_address_const::<'NOT_OWNER'>());

        // When
        let (result_policy, result_fees) = fee_mock.get_fees(token1, token2, integrator, integrator_bps);

        // Then
        assert(result_policy == FeePolicy::FeeOnBuy, 'invalid fee policy');
        assert(result_fees == 0, 'invalid fee bps');
    }
}
