use starknet::ContractAddress;

#[derive(Drop, Serde, Clone)]
pub struct Route {
    pub sell_token: ContractAddress,
    pub buy_token: ContractAddress,
    pub exchange_address: ContractAddress,
    pub percent: u128,
    pub additional_swap_params: Array<felt252>,
}
