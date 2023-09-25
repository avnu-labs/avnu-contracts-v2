#[starknet::contract]
mod MockERC20 {
    use starknet::ContractAddress;
    use avnu::interfaces::erc20::IERC20;
    use array::ArrayTrait;

    #[storage]
    struct Storage {
        balance: u256,
        expect_transfer: LegacyMap<ContractAddress, u256>,
    }

    #[derive(Drop, Serde)]
    struct Expect {
        address: ContractAddress,
        amount: u256
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
    fn constructor(ref self: ContractState, balance: u128, mut expect_transfer: Array<Expect>) {
        self.balance.write(u256 { low: balance, high: 0 });
        loop {
            match expect_transfer.pop_front() {
                Option::Some(expect) => {
                    self.expect_transfer.write(expect.address, expect.amount);
                },
                Option::None(_) => {
                    break ();
                },
            };
        };
    }

    #[external(v0)]
    impl MockERC20Impl of IERC20<ContractState> {
        fn approve(ref self: ContractState, spender: ContractAddress, amount: u256) {}

        fn transfer(ref self: ContractState, to: ContractAddress, amount: u256) {
            let expect = self.expect_transfer.read(to);
            if (expect != u256 { low: 0, high: 0 }) {
                assert(amount == expect, 'Invalid transfer amount');
            }
            self.emit(Transfer { to, amount });
        }

        fn transferFrom(
            ref self: ContractState, from: ContractAddress, to: ContractAddress, amount: u256
        ) {}

        fn balanceOf(self: @ContractState, account: ContractAddress) -> u256 {
            self.balance.read()
        }
    }
    #[generate_trait]
    impl Internal of InternalTrait {
        fn _match(self: @ContractState) {}
    }
}
