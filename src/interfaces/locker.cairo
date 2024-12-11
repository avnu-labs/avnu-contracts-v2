#[starknet::interface]
pub trait ILocker<TStorage> {
    fn locked(ref self: TStorage, id: u32, data: Array<felt252>) -> Array<felt252>;
}

#[starknet::interface]
pub trait ISwapAfterLock<TStorage> {
    fn swap_after_lock(ref self: TStorage, data: Array<felt252>);
}
