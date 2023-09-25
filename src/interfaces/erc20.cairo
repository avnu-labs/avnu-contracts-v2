use starknet::{ContractAddress};

#[starknet::interface]
trait IERC20<TStorage> {
    fn approve(ref self: TStorage, spender: ContractAddress, amount: u256);
    fn transfer(ref self: TStorage, to: ContractAddress, amount: u256);
    fn transferFrom(ref self: TStorage, from: ContractAddress, to: ContractAddress, amount: u256);
    fn balanceOf(self: @TStorage, account: ContractAddress) -> u256;
}
