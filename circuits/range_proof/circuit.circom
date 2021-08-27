include "../node_modules/circomlib/circuits/comparators.circom"
include "../node_modules/circomlib/circuits/bitify.circom"

// NB: RangeProof is inclusive.
// input: field element, whose abs is claimed to be less than max_abs_value
// output: none
// we also want something like 4 * (abs(in) + max_abs_value) < 2 ** bits
// and bits << 256
template RangeProof(bits, max_abs_value) {
    signal input in; 

    component lowerBound = LessThan(bits);
    component upperBound = LessThan(bits);

    lowerBound.in[0] <== max_abs_value + in; 
    lowerBound.in[1] <== 0;
    lowerBound.out === 0

    upperBound.in[0] <== 2 * max_abs_value;
    upperBound.in[1] <== max_abs_value + in; 
    upperBound.out === 0
}

// input: n field elements, whose abs are claimed to be less than max_abs_value
// output: none
template MultiRangeProof(n, bits) {
    signal input in[n];
    component rangeProofs[n];

    for (var i = 0; i < n; i++) {
        rangeProofs[i] = RangeProof(bits, 147946756881789309620446562439722434560);
        rangeProofs[i].in <== in[i];
    }
}