#[starknet::contract]
pub mod LayerAkiraAdapter {
    use avnu::external_solver_adapters::{IExternalSolverAdapter, SwapResponse};
    use avnu_lib::interfaces::erc20::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::syscalls::call_contract_syscall;
    #[feature("deprecated-starknet-consts")]
    use starknet::{ContractAddress, SyscallResultTrait, contract_address_const};

    const LAYERAKIRA_ADDRESS: felt252 = 0x1d62299f814ac4f360c2a3aeab1a27348434c6ddb1b2248dd873e12555c22ec;

    #[storage]
    struct Storage {}

    #[derive(Drop, Serde, Copy)]
    pub struct LayerAkiraAdapterParameters {
        pub sell_token_amount: u256,
        pub buy_token_min_amount: u256,
        pub external_solver_entrypoint: felt252,
        pub external_solver_calldata: Span<felt252>,
    }

    #[abi(embed_v0)]
    impl LayerAkiraAdapter of IExternalSolverAdapter<ContractState> {
        fn swap(
            self: @ContractState,
            user_address: ContractAddress,
            sell_token_address: ContractAddress,
            buy_token_address: ContractAddress,
            beneficiary: ContractAddress,
            external_solver_adapter_calldata: Array<felt252>,
        ) -> SwapResponse {
            let mut calldata = external_solver_adapter_calldata.span();
            let calldata = Serde::<LayerAkiraAdapterParameters>::deserialize(ref calldata).unwrap();
            let sell_token = IERC20Dispatcher { contract_address: sell_token_address };
            let buy_token = IERC20Dispatcher { contract_address: buy_token_address };

            // Retrieve user's balances before the swap
            let sell_token_balance_before = sell_token.balanceOf(beneficiary);
            let buy_token_balance_before = buy_token.balanceOf(beneficiary);

            // Execute the swap
            call_contract_syscall(
                contract_address_const::<LAYERAKIRA_ADDRESS>(), calldata.external_solver_entrypoint, calldata.external_solver_calldata,
            )
                .unwrap_syscall();

            // Verifies user's balances after the swap
            let sell_token_balance_after = sell_token.balanceOf(beneficiary);
            let buy_token_balance_after = buy_token.balanceOf(beneficiary);
            let sell_amount_used = sell_token_balance_before - sell_token_balance_after;
            let buy_amount = buy_token_balance_after - buy_token_balance_before;
            assert(sell_amount_used <= calldata.sell_token_amount, 'Invalid sell token balance');
            assert(buy_amount >= calldata.buy_token_min_amount, 'Invalid buy token balance');

            SwapResponse { sell_amount: sell_amount_used, buy_amount }
        }
    }
}
