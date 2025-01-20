use avnu::components::fee::FeePolicy;
use avnu_lib::interfaces::erc20::IERC20Dispatcher;
use starknet::ContractAddress;

#[starknet::interface]
pub trait IFeeMock<TContractState> {
    fn get_fees(
        self: @TContractState,
        sell_token_address: ContractAddress,
        buy_token_address: ContractAddress,
        integrator_fee_recipient: ContractAddress,
        integrator_fee_amount_bps: u128,
        route_len: u32,
    ) -> (FeePolicy, u128);

    fn collect_fees(
        ref self: TContractState,
        token: IERC20Dispatcher,
        amount: u256,
        fees_bps: u128,
        integrator_fee_recipient: ContractAddress,
        integrator_fee_amount_bps: u128,
    ) -> u256;
}

#[starknet::contract]
pub mod FeeMock {
    use avnu::components::fee::FeeComponent;
    use avnu_lib::components::ownable::OwnableComponent;
    use super::{ContractAddress, FeePolicy, IERC20Dispatcher, IFeeMock};

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: FeeComponent, storage: fee, event: FeeEvent);

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::OwnableInternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl FeeImpl = FeeComponent::FeeImpl<ContractState>;
    impl FeeInternalImpl = FeeComponent::FeeInternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        fee: FeeComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        FeeEvent: FeeComponent::Event,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        fees_recipient: ContractAddress,
        fees_bps_0: u128,
        fees_bps_1: u128,
        swap_exact_token_to_fees_bps: u128,
    ) {
        self.ownable.initialize(owner);
        self.fee.initialize(fees_recipient, fees_bps_0, fees_bps_1, swap_exact_token_to_fees_bps);
    }


    #[abi(embed_v0)]
    impl Mock of IFeeMock<ContractState> {
        fn get_fees(
            self: @ContractState,
            sell_token_address: ContractAddress,
            buy_token_address: ContractAddress,
            integrator_fee_recipient: ContractAddress,
            integrator_fee_amount_bps: u128,
            route_len: u32,
        ) -> (FeePolicy, u128) {
            self.fee.get_fees(sell_token_address, buy_token_address, integrator_fee_recipient, integrator_fee_amount_bps, route_len)
        }

        fn collect_fees(
            ref self: ContractState,
            token: IERC20Dispatcher,
            amount: u256,
            fees_bps: u128,
            integrator_fee_recipient: ContractAddress,
            integrator_fee_amount_bps: u128,
        ) -> u256 {
            self.fee.collect_fees(token, amount, fees_bps, integrator_fee_recipient, integrator_fee_amount_bps)
        }
    }
}
