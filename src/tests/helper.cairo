use integer::{u256, u256_from_felt252, BoundedInt};
use result::{Result, ResultTrait};
use traits::{Into, TryInto};
use array::{Array, ArrayTrait};
use option::{Option, OptionTrait};

use avnu::exchange::{Exchange, IExchangeDispatcher, IExchangeDispatcherTrait};
use avnu::tests::mocks::mock_amm::{
    MockEkubo, MockTenkSwap, MockSithSwap, MockMySwap, MockJediSwap, MockSwapAdapter
};
use avnu::tests::mocks::mock_erc20::MockERC20;
use avnu::interfaces::erc20::{IERC20Dispatcher, IERC20DispatcherTrait};
use avnu::adapters::jediswap_adapter::{
    JediswapAdapter, IJediSwapRouterDispatcher, IJediSwapRouterDispatcherTrait
};
use avnu::adapters::ekubo_adapter::{
    EkuboAdapter, IEkuboRouterDispatcher, IEkuboRouterDispatcherTrait
};
use avnu::adapters::myswap_adapter::{
    MyswapAdapter, IMySwapRouterDispatcher, IMySwapRouterDispatcherTrait
};
use avnu::adapters::sithswap_adapter::{
    SithswapAdapter, ISithSwapRouterDispatcher, ISithSwapRouterDispatcherTrait
};
use avnu::adapters::tenkswap_adapter::{
    TenkswapAdapter, ITenkSwapRouterDispatcher, ITenkSwapRouterDispatcherTrait
};
use avnu::adapters::{ISwapAdapterDispatcher, ISwapAdapterDispatcherTrait};
use starknet::{
    get_caller_address, ContractAddress, deploy_syscall, contract_address_const, ClassHash
};
use starknet::testing::{
    set_contract_address, set_caller_address, set_account_contract_address, pop_log_raw
};

fn deploy_mock_token(recipient: ContractAddress, balance: felt252) -> IERC20Dispatcher {
    let mut constructor_args: Array<felt252> = ArrayTrait::new();
    constructor_args.append(recipient.into());
    constructor_args.append(balance);
    constructor_args.append(0x0);
    let (token_address, _) = deploy_syscall(
        MockERC20::TEST_CLASS_HASH.try_into().unwrap(), 0, constructor_args.span(), false
    )
        .expect('token deploy failed');
    return IERC20Dispatcher { contract_address: token_address };
}

fn deploy_exchange() -> IExchangeDispatcher {
    let owner = contract_address_const::<0x1>();
    let constructor_args: Array<felt252> = array![0x1, 0x2];
    let (address, _) = deploy_syscall(
        Exchange::TEST_CLASS_HASH.try_into().unwrap(), 0, constructor_args.span(), false
    )
        .expect('exchange deploy failed');
    let dispatcher = IExchangeDispatcher { contract_address: address };
    set_contract_address(owner);
    let adapter_class_hash = declare_mock_swap_adapter();
    dispatcher.set_adapter_class_hash(contract_address_const::<0x12>(), adapter_class_hash);
    dispatcher.set_adapter_class_hash(contract_address_const::<0x11>(), adapter_class_hash);
    pop_log_raw(address);
    assert(pop_log_raw(address).is_none(), 'no more events');
    dispatcher
}

fn declare_mock_swap_adapter() -> ClassHash {
    MockSwapAdapter::TEST_CLASS_HASH.try_into().unwrap()
}

fn deploy_jediswap_adapter() -> ISwapAdapterDispatcher {
    let mut constructor_args: Array<felt252> = ArrayTrait::new();
    let (address, _) = deploy_syscall(
        JediswapAdapter::TEST_CLASS_HASH.try_into().unwrap(), 0, constructor_args.span(), false
    )
        .expect('jediswap adapter deploy failed');
    ISwapAdapterDispatcher { contract_address: address }
}

fn deploy_mock_jediswap() -> IJediSwapRouterDispatcher {
    let mut constructor_args: Array<felt252> = ArrayTrait::new();
    let (address, _) = deploy_syscall(
        MockJediSwap::TEST_CLASS_HASH.try_into().unwrap(), 0, constructor_args.span(), false
    )
        .expect('mock jedi deploy failed');
    IJediSwapRouterDispatcher { contract_address: address }
}

fn deploy_myswap_adapter() -> ISwapAdapterDispatcher {
    let mut constructor_args: Array<felt252> = ArrayTrait::new();
    let (address, _) = deploy_syscall(
        MyswapAdapter::TEST_CLASS_HASH.try_into().unwrap(), 0, constructor_args.span(), false
    )
        .expect('myswap adapter deploy failed');
    ISwapAdapterDispatcher { contract_address: address }
}

fn deploy_mock_myswap() -> IMySwapRouterDispatcher {
    let mut constructor_args: Array<felt252> = ArrayTrait::new();
    let (address, _) = deploy_syscall(
        MockMySwap::TEST_CLASS_HASH.try_into().unwrap(), 0, constructor_args.span(), false
    )
        .expect('mock myswap deploy failed');
    IMySwapRouterDispatcher { contract_address: address }
}

fn deploy_sithswap_adapter() -> ISwapAdapterDispatcher {
    let mut constructor_args: Array<felt252> = ArrayTrait::new();
    let (address, _) = deploy_syscall(
        SithswapAdapter::TEST_CLASS_HASH.try_into().unwrap(), 0, constructor_args.span(), false
    )
        .expect('sithswap adapter deploy failed');
    ISwapAdapterDispatcher { contract_address: address }
}

fn deploy_mock_sithswap() -> ISithSwapRouterDispatcher {
    let mut constructor_args: Array<felt252> = ArrayTrait::new();
    let (address, _) = deploy_syscall(
        MockSithSwap::TEST_CLASS_HASH.try_into().unwrap(), 0, constructor_args.span(), false
    )
        .expect('mock sithswap deploy failed');
    ISithSwapRouterDispatcher { contract_address: address }
}

fn deploy_tenkswap_adapter() -> ISwapAdapterDispatcher {
    let mut constructor_args: Array<felt252> = ArrayTrait::new();
    let (address, _) = deploy_syscall(
        TenkswapAdapter::TEST_CLASS_HASH.try_into().unwrap(), 0, constructor_args.span(), false
    )
        .expect('tenkswap adapter deploy failed');
    ISwapAdapterDispatcher { contract_address: address }
}

fn deploy_mock_tenkswap() -> ITenkSwapRouterDispatcher {
    let mut constructor_args: Array<felt252> = ArrayTrait::new();
    let (address, _) = deploy_syscall(
        MockTenkSwap::TEST_CLASS_HASH.try_into().unwrap(), 0, constructor_args.span(), false
    )
        .expect('mock tenkswap deploy failed');
    ITenkSwapRouterDispatcher { contract_address: address }
}

fn deploy_ekubo_adapter() -> ISwapAdapterDispatcher {
    let mut constructor_args: Array<felt252> = ArrayTrait::new();
    let (address, _) = deploy_syscall(
        EkuboAdapter::TEST_CLASS_HASH.try_into().unwrap(), 0, constructor_args.span(), false
    )
        .expect('ekubo adapter deploy failed');
    ISwapAdapterDispatcher { contract_address: address }
}


fn deploy_mock_ekubo() -> IEkuboRouterDispatcher {
    let mut constructor_args: Array<felt252> = ArrayTrait::new();
    let (address, _) = deploy_syscall(
        MockEkubo::TEST_CLASS_HASH.try_into().unwrap(), 0, constructor_args.span(), false
    )
        .expect('mock ekubo deploy failed');
    IEkuboRouterDispatcher { contract_address: address }
}
