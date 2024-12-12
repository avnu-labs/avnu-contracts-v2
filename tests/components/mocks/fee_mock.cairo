use avnu::components::fee::FeePolicy;
use starknet::ContractAddress;

#[starknet::interface]
pub trait IFeeMock<TContractState> {
    fn get_fees(
        self: @TContractState,
        sell_token_address: ContractAddress,
        buy_token_address: ContractAddress,
        integrator_fee_recipient: ContractAddress,
        integrator_fee_amount_bps: u128,
    ) -> (FeePolicy, u128);
}

#[starknet::contract]
pub mod FeeMock {
    use avnu::components::fee::FeeComponent;
    use avnu::components::fee::FeeComponent::FeeInternalImpl;
    use avnu_lib::components::ownable::OwnableComponent;
    use avnu_lib::components::ownable::OwnableComponent::OwnableInternalImpl;
    use super::{ContractAddress, FeePolicy, IFeeMock};

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: FeeComponent, storage: fee, event: FeeEvent);

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;

    #[abi(embed_v0)]
    impl FeeImpl = FeeComponent::FeeImpl<ContractState>;

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
        ref self: ContractState, owner: ContractAddress, fees_recipient: ContractAddress, fees_bps: u128, swap_exact_token_to_fees_bps: u128,
    ) {
        self.ownable.initialize(owner);
        self.fee.initialize(fees_recipient, fees_bps, swap_exact_token_to_fees_bps);
    }


    #[abi(embed_v0)]
    impl Mock of IFeeMock<ContractState> {
        fn get_fees(
            self: @ContractState,
            sell_token_address: ContractAddress,
            buy_token_address: ContractAddress,
            integrator_fee_recipient: ContractAddress,
            integrator_fee_amount_bps: u128,
        ) -> (FeePolicy, u128) {
            self.fee.get_fees(sell_token_address, buy_token_address, integrator_fee_recipient, integrator_fee_amount_bps)
        }
    }
}
