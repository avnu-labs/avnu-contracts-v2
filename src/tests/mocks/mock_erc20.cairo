use starknet::ContractAddress;

#[starknet::interface]
trait IERC20<TStorage> {
    fn approve(ref self: TStorage, spender: ContractAddress, amount: u256);
    fn transfer(ref self: TStorage, to: ContractAddress, amount: u256);
    fn transferFrom(ref self: TStorage, from: ContractAddress, to: ContractAddress, amount: u256);
    fn balanceOf(self: @TStorage, account: ContractAddress) -> u256;
    fn mint(ref self: TStorage, account: ContractAddress, amount: u256);
    fn burn(ref self: TStorage, account: ContractAddress, amount: u256);
}


#[starknet::contract]
mod MockERC20 {
    use integer::BoundedInt;
    use super::IERC20;
    use starknet::ContractAddress;
    use starknet::get_caller_address;

    #[storage]
    struct Storage {
        ERC20_total_supply: u256,
        ERC20_balances: LegacyMap<ContractAddress, u256>,
        ERC20_allowances: LegacyMap<(ContractAddress, ContractAddress), u256>,
    }

    #[event]
    #[derive(starknet::Event, Drop, PartialEq)]
    enum Event {
        transfer: Transfer,
    }

    #[derive(Drop, starknet::Event, PartialEq)]
    struct Transfer {
        to: ContractAddress,
        amount: u256,
    }

    #[constructor]
    fn constructor(ref self: ContractState, recipient: ContractAddress, initial_supply: u256,) {
        self._mint(recipient, initial_supply);
    }

    #[external(v0)]
    impl ERC20Impl of IERC20<ContractState> {
        fn balanceOf(self: @ContractState, account: ContractAddress) -> u256 {
            self.ERC20_balances.read(account)
        }

        fn transfer(ref self: ContractState, to: ContractAddress, amount: u256) {
            let sender = get_caller_address();
            self._transfer(sender, to, amount);
            self.emit(Transfer { to, amount });
        }

        fn transferFrom(
            ref self: ContractState, from: ContractAddress, to: ContractAddress, amount: u256
        ) {
            let caller = get_caller_address();
            self._spend_allowance(from, caller, amount);
            self._transfer(from, to, amount);
        }

        fn approve(ref self: ContractState, spender: ContractAddress, amount: u256) {
            let caller = get_caller_address();
            self._approve(caller, spender, amount);
        }

        fn mint(ref self: ContractState, account: ContractAddress, amount: u256) {
            self._mint(account, amount)
        }
        fn burn(ref self: ContractState, account: ContractAddress, amount: u256) {
            self._burn(account, amount)
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _transfer(
            ref self: ContractState,
            sender: ContractAddress,
            recipient: ContractAddress,
            amount: u256
        ) {
            self.ERC20_balances.write(sender, self.ERC20_balances.read(sender) - amount);
            self.ERC20_balances.write(recipient, self.ERC20_balances.read(recipient) + amount);
        }

        fn _approve(
            ref self: ContractState, owner: ContractAddress, spender: ContractAddress, amount: u256
        ) {
            self.ERC20_allowances.write((owner, spender), amount);
        }

        fn _mint(ref self: ContractState, recipient: ContractAddress, amount: u256) {
            self.ERC20_total_supply.write(self.ERC20_total_supply.read() + amount);
            self.ERC20_balances.write(recipient, self.ERC20_balances.read(recipient) + amount);
        }

        fn _burn(ref self: ContractState, account: ContractAddress, amount: u256) {
            self.ERC20_total_supply.write(self.ERC20_total_supply.read() - amount);
            self.ERC20_balances.write(account, self.ERC20_balances.read(account) - amount);
        }

        fn _spend_allowance(
            ref self: ContractState, owner: ContractAddress, spender: ContractAddress, amount: u256
        ) {
            let current_allowance = self.ERC20_allowances.read((owner, spender));
            if current_allowance != BoundedInt::max() {
                self._approve(owner, spender, current_allowance - amount);
            }
        }
    }
}
