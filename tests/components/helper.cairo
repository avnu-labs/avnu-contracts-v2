use avnu::components::fee::IFeeDispatcher;
use avnu_lib::interfaces::erc20::IERC20Dispatcher;
use starknet::syscalls::deploy_syscall;
use starknet::testing::pop_log_raw;
#[feature("deprecated-starknet-consts")]
use starknet::{ContractAddress, contract_address_const};
use super::mocks::fee_mock::{FeeMock, IFeeMockDispatcher};
use super::mocks::mock_erc20::MockERC20;

pub fn deploy_fee() -> IFeeDispatcher {
    let mut calldata = array!['OWNER', 'FEES_RECIPIENT', 0, 0, 30];
    let (address, _) = deploy_syscall(FeeMock::TEST_CLASS_HASH.try_into().unwrap(), 0, calldata.span(), false).expect('Failed to deploy FeeMock');
    pop_log_raw(address).unwrap();
    IFeeDispatcher { contract_address: address }
}

pub fn deploy_fee_with_defaults() -> (IFeeDispatcher, IFeeMockDispatcher) {
    let mut calldata = array!['OWNER', 'FEES_RECIPIENT', 50, 100, 100];
    let (address, _) = deploy_syscall(FeeMock::TEST_CLASS_HASH.try_into().unwrap(), 0, calldata.span(), false).expect('Failed to deploy FeeMock');
    pop_log_raw(address).unwrap();
    (IFeeDispatcher { contract_address: address }, IFeeMockDispatcher { contract_address: address })
}

pub fn get_common_actors() -> (ContractAddress, ContractAddress, ContractAddress) {
    let sell_token: ContractAddress = contract_address_const::<'SELL_TOKEN'>();
    let buy_token: ContractAddress = contract_address_const::<'BUY_TOKEN'>();
    let integrator_recipient: ContractAddress = contract_address_const::<'INTEGRATOR'>();

    return (sell_token, buy_token, integrator_recipient);
}

pub fn deploy_mock_token(recipient: ContractAddress, balance: felt252, salt: felt252) -> IERC20Dispatcher {
    let mut constructor_args: Array<felt252> = ArrayTrait::new();
    constructor_args.append(recipient.into());
    constructor_args.append(balance);
    constructor_args.append(0x0);
    let (token_address, _) = deploy_syscall(MockERC20::TEST_CLASS_HASH.try_into().unwrap(), salt, constructor_args.span(), false)
        .expect('token deploy failed');
    return IERC20Dispatcher { contract_address: token_address };
}

pub fn deploy_fee_with_address() -> (IFeeDispatcher, IFeeMockDispatcher, ContractAddress) {
    let mut calldata = array!['OWNER', 'FEES_RECIPIENT', 0, 0, 30];
    let (address, _) = deploy_syscall(FeeMock::TEST_CLASS_HASH.try_into().unwrap(), 0, calldata.span(), false).expect('Failed to deploy FeeMock');
    pop_log_raw(address).unwrap();
    return (IFeeDispatcher { contract_address: address }, IFeeMockDispatcher { contract_address: address }, address);
}
