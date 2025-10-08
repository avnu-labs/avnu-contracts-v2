use starknet::ContractAddress;

// hex("branch") == 0x6272616e6368 == 108243400418152
const BRANCH_MARKER: felt252 = 108243400418152;

#[derive(Drop, Serde, Clone)]
pub struct Route {
    pub sell_token: ContractAddress,
    pub buy_token: ContractAddress,
    pub swap: RouteSwap,
}

#[derive(Drop, Clone)]
pub enum RouteSwap {
    Direct: DirectSwap,
    Branch: BranchSwap,
}

impl RouteSwapSerde of Serde<RouteSwap> {
    fn serialize(self: @RouteSwap, ref output: Array<felt252>) {
        match self {
            RouteSwap::Direct(route) => Serde::serialize(route, ref output),
            RouteSwap::Branch(route) => {
                output.append(BRANCH_MARKER);
                Serde::serialize(route, ref output)
            },
        }
    }

    fn deserialize(ref serialized: Span<felt252>) -> Option<RouteSwap> {
        let optional_marker = serialized.get(0)?.unbox().clone();

        Option::Some(
            if optional_marker == BRANCH_MARKER {
                // Consume marker first
                let _: felt252 = Serde::deserialize(ref serialized)?;

                RouteSwap::Branch(Serde::deserialize(ref serialized)?)
            } else {
                RouteSwap::Direct(Serde::deserialize(ref serialized)?)
            },
        )
    }
}

#[derive(Drop, Serde, Clone)]
pub struct DirectSwap {
    pub exchange_address: ContractAddress,
    pub percent: u128,
    pub additional_swap_params: Array<felt252>,
}

#[derive(Drop, Serde, Clone)]
pub struct AlternativeSwap {
    pub exchange_address: ContractAddress,
    pub percent: u128,
    pub minimum_price: u256,
    pub additional_swap_params: Array<felt252>,
}

#[derive(Drop, Serde, Clone)]
pub struct BranchSwap {
    pub principal: DirectSwap,
    pub alternatives: Array<AlternativeSwap>,
}
