use starknet::ContractAddress;

#[starknet::interface]
trait INostraRouter<TContractState> {
    fn swap_exact_tokens_for_tokens(
        self: @TContractState,
        amount_in: u256,
        amount_out_min: u256,
        path: Span<ContractAddress>,
        swap_fees: Span<u16>,
        to: ContractAddress,
        deadline: u64
    ) -> Array<u256>;
}

#[starknet::contract]
mod NostraAdapter {
    use avnu::adapters::ISwapAdapter;
    use avnu::interfaces::erc20::{IERC20Dispatcher, IERC20DispatcherTrait};
    use super::{INostraRouterDispatcher, INostraRouterDispatcherTrait};
    use starknet::{get_block_timestamp, ContractAddress};
    use array::ArrayTrait;
    use traits::TryInto;

    #[storage]
    struct Storage {}

    #[external(v0)]
    impl NostraAdapter of ISwapAdapter<ContractState> {
        fn swap(
            self: @ContractState,
            exchange_address: ContractAddress,
            token_from_address: ContractAddress,
            token_from_amount: u256,
            token_to_address: ContractAddress,
            token_to_min_amount: u256,
            to: ContractAddress,
            additional_swap_params: Array<felt252>,
        ) {
            assert(additional_swap_params.len() == 1, 'Invalid swap params');

            // Init path
            let path = array![token_from_address, token_to_address];

            // Init path
            let swap_fee: felt252 = *additional_swap_params[0];
            let swap_fees: Array<u16> = array![swap_fee.try_into().unwrap()];

            // Init deadline
            let block_timestamp = get_block_timestamp();
            let deadline = block_timestamp;

            IERC20Dispatcher { contract_address: token_from_address }
                .approve(exchange_address, token_from_amount);
            INostraRouterDispatcher { contract_address: exchange_address }
                .swap_exact_tokens_for_tokens(
                    token_from_amount,
                    token_to_min_amount,
                    path.span(),
                    swap_fees.span(),
                    to,
                    deadline
                );
        }
    }
}
