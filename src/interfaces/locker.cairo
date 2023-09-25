#[starknet::interface]
trait ILocker<TStorage> {
    fn locked(ref self: TStorage, id: u32, data: Array<felt252>) -> Array<felt252>;
}

#[starknet::interface]
trait ISwapAfterLock<TStorage> {
    fn swap_after_lock(ref self: TStorage, data: Array<felt252>);
}
