mod ComputeSqrtRatioLimit {
    use avnu::math::sqrt_ratio::compute_sqrt_ratio_limit;
    const MIN: u256 = 18446748437148339061;
    const MAX: u256 = 6277100250585753475930931601400621808602321654880405518632;

    #[test]
    fn should_return_min_when_u256_sub_Overflow() {
        // Given
        let sqrt_ratio = 1844674843714833906100;
        let distance = 18446748437148339061000;
        let is_token1 = false;

        // When
        let result = compute_sqrt_ratio_limit(sqrt_ratio, distance, is_token1, MIN, MAX);

        // Then
        assert(result == 18446748437148339061, 'invalid sqrt_ratio');
    }

    #[test]
    fn should_return_max_when_u256_add_Overflow() {
        // Given
        let sqrt_ratio =
            97896044618658097711785492504343953926634992332820282019728792003956564819967;
        let distance =
            57896044618658097711785492504343953926634992332820282019728792003956564819967;
        let is_token1 = true;

        // When
        let result = compute_sqrt_ratio_limit(sqrt_ratio, distance, is_token1, MIN, MAX);

        // Then
        assert(
            result == 6277100250585753475930931601400621808602321654880405518632,
            'invalid sqrt_ratio'
        );
    }

    #[test]
    fn should_return_value_when_token0() {
        // Given
        let sqrt_ratio = 28446748437148339155;
        let distance = 123;
        let is_token1 = false;

        // When
        let result = compute_sqrt_ratio_limit(sqrt_ratio, distance, is_token1, MIN, MAX);

        // Then
        assert(result == 28446748437148339032, 'invalid sqrt_ratio');
    }

    #[test]
    fn should_return_value_when_token1() {
        // Given
        let sqrt_ratio = 28446748437148339061;
        let distance = 123;
        let is_token1 = true;

        // When
        let result = compute_sqrt_ratio_limit(sqrt_ratio, distance, is_token1, MIN, MAX);

        // Then
        assert(result == 28446748437148339184, 'invalid sqrt_ratio');
    }
}
