fn compute_sqrt_ratio_limit(
    sqrt_ratio: u256, distance: u256, is_token1: bool, min: u256, max: u256
) -> u256 {
    let mut sqrt_ratio_limit = if is_token1 {
        if (distance > max) {
            max
        } else {
            sqrt_ratio + distance
        }
    } else {
        if (distance > sqrt_ratio) {
            min
        } else {
            sqrt_ratio - distance
        }
    };
    if (sqrt_ratio_limit < min) {
        sqrt_ratio_limit = min;
    }
    if (sqrt_ratio_limit > max) {
        sqrt_ratio_limit = max;
    }
    sqrt_ratio_limit
}
