use avnu::components::fee::IFeeDispatcher;
use starknet::syscalls::deploy_syscall;
use starknet::testing::pop_log_raw;
use super::mocks::fee_mock::FeeMock;

pub fn deploy_fee() -> IFeeDispatcher {
    let mut calldata = array!['OWNER', 'FEES_RECIPIENT', 10, 10];
    let (address, _) = deploy_syscall(FeeMock::TEST_CLASS_HASH.try_into().unwrap(), 0, calldata.span(), false).expect('Failed to deploy FeeMock');
    pop_log_raw(address).unwrap();
    IFeeDispatcher { contract_address: address }
}
