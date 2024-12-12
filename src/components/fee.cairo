use starknet::ContractAddress;

#[derive(Drop, Serde, Debug, PartialEq, starknet::Store)]
pub struct TokenFeeConfig {
    pub weight: u32,
    pub fee_on_buy: Option<u128>,
    pub fee_on_sell: Option<u128>,
}

#[derive(Drop, Serde, Debug, PartialEq)]
pub enum FeePolicy {
    FeeOnBuy,
    FeeOnSell,
}

#[starknet::interface]
pub trait IFee<TContractState> {
    fn get_fees_recipient(self: @TContractState) -> ContractAddress;
    fn set_fees_recipient(ref self: TContractState, fees_recipient: ContractAddress) -> bool;
    fn get_fees_bps(self: @TContractState) -> u128;
    fn set_fees_bps(ref self: TContractState, bps: u128) -> bool;
    fn get_swap_exact_token_to_fees_bps(self: @TContractState) -> u128;
    fn set_swap_exact_token_to_fees_bps(ref self: TContractState, bps: u128) -> bool;
    fn get_token_fee_config(self: @TContractState, token: ContractAddress) -> TokenFeeConfig;
    fn set_token_fee_config(ref self: TContractState, token: ContractAddress, config: TokenFeeConfig) -> bool;
    fn get_pair_specific_fees(self: @TContractState, token_a: ContractAddress, token_b: ContractAddress) -> Option<u128>;
    fn set_pair_specific_fees(ref self: TContractState, token_a: ContractAddress, token_b: ContractAddress, fee_bps: Option<u128>) -> bool;
    fn is_integrator_whitelisted(self: @TContractState, integrator: ContractAddress) -> bool;
    fn set_whitelisted_integrator(ref self: TContractState, integrator: ContractAddress, whitelisted: bool) -> bool;
}

#[starknet::component]
pub mod FeeComponent {
    use avnu_lib::components::ownable::OwnableComponent;
    use avnu_lib::components::ownable::OwnableComponent::OwnableInternalImpl;
    use avnu_lib::interfaces::erc20::{IERC20Dispatcher, IERC20DispatcherTrait};
    use avnu_lib::math::muldiv::muldiv;
    use core::cmp::min;
    use core::num::traits::Zero;
    use core::option::OptionTrait;
    use starknet::ContractAddress;
    use starknet::storage::Map;
    use starknet::storage::{StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess, StoragePointerWriteAccess};

    use super::{FeePolicy, TokenFeeConfig};

    const MAX_AVNU_FEES_BPS: u128 = 100;
    const MAX_INTEGRATOR_FEES_BPS: u128 = 500;

    #[storage]
    pub struct Storage {
        // The default amount of fees in bps
        fees_bps: u128,
        // The amount of fees in bps that we try to collect if user doesn't get the expected amount of buy token
        // during the first interation of swapExactTokenTo.
        swap_exact_token_to_fees_bps: u128,
        // The address that will receive the fees
        fees_recipient: ContractAddress,
        // The specific fee configuration for a given token address.
        // Defines the weight (to know if we take fees on buy or sell)
        // It can also define specific fee amount in bps for buy or sell. The lowest fee amount will be selected
        token_fees: Map<ContractAddress, TokenFeeConfig>,
        // Defines a specific fee amount in bps for a given pair of token addresses
        pair_specific_fees: Map<(ContractAddress, ContractAddress), Option<u128>>,
        // Defines the list of whitelisted integrator.
        // With don't take any fee if the integrator's fee amount is greater or equal to ours
        whitelisted_integrators: Map<ContractAddress, bool>,
    }

    #[event]
    #[derive(Drop, PartialEq, starknet::Event)]
    pub enum Event {}

    #[embeddable_as(FeeImpl)]
    pub impl Fee<
        TContractState, +HasComponent<TContractState>, impl Ownable: OwnableComponent::HasComponent<TContractState>, +Drop<TContractState>,
    > of super::IFee<ComponentState<TContractState>> {
        fn get_fees_recipient(self: @ComponentState<TContractState>) -> ContractAddress {
            self.fees_recipient.read()
        }

        fn set_fees_recipient(ref self: ComponentState<TContractState>, fees_recipient: ContractAddress) -> bool {
            get_dep_component!(@self, Ownable).assert_only_owner();
            self.fees_recipient.write(fees_recipient);
            true
        }

        fn get_fees_bps(self: @ComponentState<TContractState>) -> u128 {
            self.fees_bps.read()
        }

        fn set_fees_bps(ref self: ComponentState<TContractState>, bps: u128) -> bool {
            get_dep_component!(@self, Ownable).assert_only_owner();
            assert(bps <= MAX_AVNU_FEES_BPS, 'Fees are too high');
            self.fees_bps.write(bps);
            true
        }

        fn get_swap_exact_token_to_fees_bps(self: @ComponentState<TContractState>) -> u128 {
            self.swap_exact_token_to_fees_bps.read()
        }

        fn set_swap_exact_token_to_fees_bps(ref self: ComponentState<TContractState>, bps: u128) -> bool {
            get_dep_component!(@self, Ownable).assert_only_owner();
            assert(bps <= MAX_AVNU_FEES_BPS, 'Fees are too high');
            self.swap_exact_token_to_fees_bps.write(bps);
            true
        }

        fn get_token_fee_config(self: @ComponentState<TContractState>, token: ContractAddress) -> TokenFeeConfig {
            self.token_fees.read(token)
        }

        fn set_token_fee_config(ref self: ComponentState<TContractState>, token: ContractAddress, config: TokenFeeConfig) -> bool {
            get_dep_component!(@self, Ownable).assert_only_owner();
            self.token_fees.write(token, config);
            true
        }

        fn get_pair_specific_fees(self: @ComponentState<TContractState>, token_a: ContractAddress, token_b: ContractAddress) -> Option<u128> {
            self.pair_specific_fees.read(get_pair_key(token_a, token_b))
        }

        fn set_pair_specific_fees(
            ref self: ComponentState<TContractState>, token_a: ContractAddress, token_b: ContractAddress, fee_bps: Option<u128>,
        ) -> bool {
            get_dep_component!(@self, Ownable).assert_only_owner();
            self.pair_specific_fees.write(get_pair_key(token_a, token_b), fee_bps);
            true
        }

        fn is_integrator_whitelisted(self: @ComponentState<TContractState>, integrator: ContractAddress) -> bool {
            self.whitelisted_integrators.read(integrator)
        }

        fn set_whitelisted_integrator(ref self: ComponentState<TContractState>, integrator: ContractAddress, whitelisted: bool) -> bool {
            get_dep_component!(@self, Ownable).assert_only_owner();
            self.whitelisted_integrators.write(integrator, whitelisted);
            true
        }
    }

    #[generate_trait]
    pub impl FeeInternalImpl<TContractState, +HasComponent<TContractState>> of FeeInternal<TContractState> {
        fn initialize(ref self: ComponentState<TContractState>, fees_recipient: ContractAddress, fees_bps: u128, swap_exact_token_to_fees_bps: u128) {
            self.fees_recipient.write(fees_recipient);
            self.fees_bps.write(fees_bps);
            self.swap_exact_token_to_fees_bps.write(fees_bps);
        }

        fn get_fees(
            self: @ComponentState<TContractState>,
            sell_token_address: ContractAddress,
            buy_token_address: ContractAddress,
            integrator_fee_recipient: ContractAddress,
            integrator_fee_amount_bps: u128,
        ) -> (FeePolicy, u128) {
            // First we retrieve the fee configuration for the two tokens
            let sell_token_fee_config = self.token_fees.read(sell_token_address);
            let buy_token_fee_config = self.token_fees.read(buy_token_address);

            // Thanks to the weight we can determine if we take fees on buy or sell
            let policy = if (buy_token_fee_config.weight >= sell_token_fee_config.weight) {
                FeePolicy::FeeOnBuy
            } else {
                FeePolicy::FeeOnSell
            };

            // If we have a specific fee for the pair of token we use it
            let fees_bps = if let Option::Some(specific_fees) = self.pair_specific_fees.read(get_pair_key(sell_token_address, buy_token_address)) {
                specific_fees
            } else {
                // If no specific fee on pair we take the lowest fee amount between the two tokens
                // A token config can define a specific amount when sold or bought
                // If the amount isn't defined we take the default amount
                let default_bps = self.fees_bps.read();
                let sell_token_fee = sell_token_fee_config.fee_on_sell.unwrap_or(default_bps);
                let buy_token_fee = buy_token_fee_config.fee_on_buy.unwrap_or(default_bps);
                min(sell_token_fee, buy_token_fee)
            };

            let is_integrator_whitelisted = self.whitelisted_integrators.read(integrator_fee_recipient);
            if (is_integrator_whitelisted && integrator_fee_amount_bps >= fees_bps) {
                return (policy, 0);
            }

            (policy, fees_bps)
        }

        // Collects fees and returns the remaing amount of token
        fn collect_fees(
            ref self: ComponentState<TContractState>,
            token: IERC20Dispatcher,
            amount: u256,
            fees_bps: u128,
            integrator_fee_recipient: ContractAddress,
            integrator_fee_amount_bps: u128,
        ) -> u256 {
            // Collect integrator's fees
            assert(integrator_fee_amount_bps <= MAX_INTEGRATOR_FEES_BPS, 'Integrator fees are too high');
            let integrator_fees_collected = self.collect_fee_bps(token, amount, integrator_fee_recipient, integrator_fee_amount_bps);

            // Collect AVNU's fees
            let avnu_fees_collected = self.collect_fee_bps(token, amount, self.fees_recipient.read(), fees_bps);

            // Return amount minus fees
            amount - integrator_fees_collected - avnu_fees_collected
        }

        fn collect_fee_bps(
            ref self: ComponentState<TContractState>, token: IERC20Dispatcher, amount: u256, fee_recipient: ContractAddress, fee_amount_bps: u128,
        ) -> u256 {
            if (!fee_amount_bps.is_zero() && !fee_recipient.is_zero()) {
                // Compute fee amount
                let (fee_amount, overflows) = muldiv(amount, fee_amount_bps.into(), 10000_u256, false);
                assert(overflows == false, 'Overflow: Invalid fee');

                // Collect fees from contract
                token.transfer(fee_recipient, fee_amount);

                fee_amount
            } else {
                0
            }
        }
    }

    fn get_pair_key(token_a: ContractAddress, token_b: ContractAddress) -> (ContractAddress, ContractAddress) {
        if token_a < token_b {
            (token_a, token_b)
        } else {
            (token_b, token_a)
        }
    }
}
