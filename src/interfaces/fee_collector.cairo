#[derive(Drop, Serde)]
struct FeeInfo {
    is_active: bool,
    fee_type: u128,
    fee_amount: u128
}

#[starknet::interface]
trait IFeeCollector<TStorage> {
    fn feeInfo(self: @TStorage) -> FeeInfo;
}
