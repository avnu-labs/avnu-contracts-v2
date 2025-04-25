use starknet::ContractAddress;
use super::mock_erc20::{IERC20Dispatcher, IERC20DispatcherTrait};

#[starknet::interface]
pub trait ISwap<TContractState> {
    fn swap(
        ref self: TContractState,
        user_address: ContractAddress,
        sell_token_address: ContractAddress,
        sell_amount: u256,
        buy_token_address: ContractAddress,
    );
}


#[starknet::contract]
pub mod MockLayerAkira {
    use starknet::ContractAddress;
    use super::{IERC20Dispatcher, IERC20DispatcherTrait, ISwap};

    #[storage]
    struct Storage {}

    #[abi(embed_v0)]
    impl RouterImpl of ISwap<ContractState> {
        fn swap(
            ref self: ContractState,
            user_address: ContractAddress,
            sell_token_address: ContractAddress,
            sell_amount: u256,
            buy_token_address: ContractAddress,
        ) {
            IERC20Dispatcher { contract_address: sell_token_address }.burn(user_address, sell_amount);
            IERC20Dispatcher { contract_address: buy_token_address }.mint(user_address, sell_amount);
        }
    }
}
