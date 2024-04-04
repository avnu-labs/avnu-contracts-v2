use starknet::ContractAddress;

#[starknet::interface]
trait INostraV2Router<TContractState> {
    fn swap_exact_tokens_for_tokens(
        self: @TContractState,
        amount_in: u256,
        amount_out_min: u256,
        token_in: ContractAddress,
        pairs: Span<ContractAddress>,
        to: ContractAddress,
        deadline: u64
    ) -> Array<u256>;
}

#[starknet::contract]
mod NostraV2Adapter {
    use avnu::adapters::ISwapAdapter;
    use avnu::interfaces::erc20::{IERC20Dispatcher, IERC20DispatcherTrait};
    use super::{INostraV2RouterDispatcher, INostraV2RouterDispatcherTrait};
    use starknet::{get_block_timestamp, ContractAddress};
    use array::ArrayTrait;
    use traits::TryInto;

    #[storage]
    struct Storage {}

    #[external(v0)]
    impl NostraV2Adapter of ISwapAdapter<ContractState> {
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

            // Init pair
            let pair: ContractAddress = (*additional_swap_params[0]).try_into().unwrap();
            let pairs = array![pair];

            // Init deadline
            let block_timestamp = get_block_timestamp();
            let deadline = block_timestamp;

            IERC20Dispatcher { contract_address: token_from_address }
                .approve(exchange_address, token_from_amount);
            INostraV2RouterDispatcher { contract_address: exchange_address }
                .swap_exact_tokens_for_tokens(
                    token_from_amount,
                    token_to_min_amount,
                    token_from_address,
                    pairs.span(),
                    to,
                    deadline
                );
        }
    }
}
