use starknet::ContractAddress;

#[starknet::interface]
pub trait INostraV2Router<TContractState> {
    fn swap_exact_tokens_for_tokens(
        self: @TContractState,
        amount_in: u256,
        amount_out_min: u256,
        token_in: ContractAddress,
        pairs: Span<ContractAddress>,
        to: ContractAddress,
        deadline: u64,
    ) -> Array<u256>;
}

#[starknet::contract]
pub mod NostraV2Adapter {
    use avnu::adapters::ISwapAdapter;
    use avnu_lib::interfaces::erc20::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::{ContractAddress, get_block_timestamp};
    use super::{INostraV2RouterDispatcher, INostraV2RouterDispatcherTrait};

    #[storage]
    struct Storage {}

    #[abi(embed_v0)]
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

            IERC20Dispatcher { contract_address: token_from_address }.approve(exchange_address, token_from_amount);
            INostraV2RouterDispatcher { contract_address: exchange_address }
                .swap_exact_tokens_for_tokens(token_from_amount, token_to_min_amount, token_from_address, pairs.span(), to, deadline);
        }
    }
}
