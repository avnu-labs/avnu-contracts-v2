use starknet::ContractAddress;

#[derive(Drop, Serde)]
struct Route {
    token_from: ContractAddress,
    token_to: ContractAddress,
    exchange_address: ContractAddress,
    percent: u128,
    additional_swap_params: Array<felt252>,
}
