#[starknet::contract]
mod MockFeeCollector {
    use avnu::interfaces::fee_collector::{IFeeCollector, FeeInfo};

    #[storage]
    struct Storage {
        is_active: bool,
        fee_type: u128,
        fee_amount: u128
    }

    #[constructor]
    fn constructor(ref self: ContractState, is_active: bool, fee_type: u128, fee_amount: u128) {
        self.is_active.write(is_active);
        self.fee_type.write(fee_type);
        self.fee_amount.write(fee_amount);
    }

    #[external(v0)]
    impl MockFeeCollectorImpl of IFeeCollector<ContractState> {
        fn feeInfo(self: @ContractState) -> FeeInfo {
            FeeInfo {
                is_active: self.is_active.read(),
                fee_type: self.fee_type.read(),
                fee_amount: self.fee_amount.read(),
            }
        }
    }
}
