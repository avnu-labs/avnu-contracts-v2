use starknet::ContractAddress;

#[derive(Drop, Copy, Serde)]
pub struct OpenNoteDeposit {
    pub note_id: felt252,
    pub token: ContractAddress,
    pub amount: u128,
}

#[starknet::interface]
pub trait IPrivacySwapHelper<T> {
    fn privacy_invoke(ref self: T, buy_token: ContractAddress, calls: Span<starknet::account::Call>, note_id: felt252) -> Span<OpenNoteDeposit>;
}

#[starknet::contract]
mod PrivacySwapHelper {
    use avnu_lib::interfaces::erc20::{IERC20Dispatcher, IERC20DispatcherTrait};
    use core::num::traits::Zero;
    use starknet::account::Call;
    use starknet::syscalls::call_contract_syscall;
    use starknet::{ContractAddress, SyscallResultTrait, get_caller_address, get_contract_address};
    use super::{IPrivacySwapHelper, OpenNoteDeposit};

    #[storage]
    struct Storage {}

    #[abi(embed_v0)]
    impl PrivacySwapHelperImpl of IPrivacySwapHelper<ContractState> {
        fn privacy_invoke(ref self: ContractState, buy_token: ContractAddress, calls: Span<Call>, note_id: felt252) -> Span<OpenNoteDeposit> {
            assert!(buy_token.is_non_zero(), "buy_token is zero");
            assert!(calls.len() > 0, "calls is empty");

            let buy_erc20 = IERC20Dispatcher { contract_address: buy_token };
            let self_addr = get_contract_address();
            let balance_before = buy_erc20.balanceOf(self_addr);

            for call in calls {
                call_contract_syscall(*call.to, *call.selector, *call.calldata).unwrap_syscall();
            }

            let received: u128 = (buy_erc20.balanceOf(self_addr) - balance_before).try_into().expect('RECEIVED_OVERFLOW');
            assert!(received.is_non_zero(), "zero output");

            buy_erc20.approve(get_caller_address(), received.into());

            [OpenNoteDeposit { note_id, token: buy_token, amount: received }].span()
        }
    }
}
