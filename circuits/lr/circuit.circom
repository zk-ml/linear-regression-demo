include "../node_modules/circomlib/circuits/comparators.circom";
include "../node_modules/circomlib/circuits/switcher.circom";
include "../node_modules/circomlib/circuits/sign.circom"
include "../node_modules/circomlib/circuits/bitify.circom"

include "../utils/encrypt.circom";
include "../utils/ecdh.circom";

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

template IsNegative(){
    signal input in;
    signal output out;
    component n2b = Num2Bits(254);
    component sign = Sign();
    in ==> n2b.in;
    for (var i = 0; i<254; i++) {
        n2b.out[i] ==> sign.in[i];
    }
    sign.sign ==> out;
}


// input: dividend and divisor field elements in [0, sqrt(p))
// output: remainder and quotient field elements in [0, p-1] and [0, sqrt(p)
// Haven't thought about negative divisor yet. Not needed.
// -8 % 5 = 2. [-8 -> 8. 8 % 5 -> 3. 5 - 3 -> 2.]
// (-8 - 2) // 5 = -2
// -8 + 2 * 5 = 2
// check: 2 - 2 * 5 = -8
template Modulo(divisor_bits) {
    signal input dividend; // -8
    signal input divisor; // 5
    signal output remainder; // 2
    signal output quotient; // -2
 
    component is_neg = IsNegative();
    is_neg.in <== dividend;
 
    signal output is_dividend_negative;
    is_dividend_negative <== is_neg.out;
 
    signal output dividend_adjustment;
    dividend_adjustment <== 1 + is_dividend_negative * -2; // 1 or -1
 
    signal output abs_dividend;
    abs_dividend <== dividend * dividend_adjustment; // 8
 
    signal output raw_remainder;
    raw_remainder <-- abs_dividend % divisor;
 
    signal output neg_remainder;
    neg_remainder <-- divisor - raw_remainder;
 
    if (is_dividend_negative == 1 && raw_remainder != 0) {
        remainder <-- neg_remainder;
    } else {
        remainder <-- raw_remainder;
    }
 
    quotient <-- (dividend - remainder) / divisor; // (-8 - 2) / 5 = -2.
 
    dividend === divisor * quotient + remainder; // -8 = 5 * -2 + 2.
 
    component rp = MultiRangeProof(3, 128);
    rp.in[0] <== divisor;
    rp.in[1] <== quotient;
    rp.in[2] <== dividend;
    //rp.max_abs_value <== SQRT_P;
 
    // check that 0 <= remainder < divisor
    component remainderUpper = LessThan(divisor_bits);
    remainderUpper.in[0] <== remainder;
    remainderUpper.in[1] <== divisor;
    remainderUpper.out === 1;
}

template quant_error(m, n) {
    signal input Y_q[m][n];
    signal input Yt_q[m][n];
    signal output out[m][n];
    signal input sYsR_numerator;
    signal input sYsR_denominator;
    signal input sYtsR_numerator;
    signal input sYtsR_denominator;
    signal input constant;
    signal Y_q_mul[m][n];
    signal Yt_q_mul[m][n];
    signal Y_q_div[m][n];
    signal Yt_q_div[m][n];

    component div1[m][n];
    component div2[m][n];
    for (var i = 0; i < m; i++) {
        for (var j = 0; j < n; j++) {
            Y_q_mul[i][j] <== Y_q[i][j] * sYsR_numerator;
            Yt_q_mul[i][j] <== Yt_q[i][j] * sYtsR_numerator;
        }
    }

    for (var i = 0; i < m; i++) {
        for (var j = 0; j < n; j++) {
            div1[i][j] = Modulo(64);
            div2[i][j] = Modulo(64);
            div1[i][j].dividend <== Y_q_mul[i][j];
            div2[i][j].dividend <== Yt_q_mul[i][j];
            div1[i][j].divisor <== sYsR_denominator;
            div2[i][j].divisor <== sYtsR_denominator;
            div1[i][j].quotient ==> Y_q_div[i][j];
            div2[i][j].quotient ==> Yt_q_div[i][j];
        }
    }

    for (var i = 0; i < m; i++) {
        for (var j = 0; j < n; j++) {
            out[i][j] <== constant + Y_q_div[i][j] - Yt_q_div[i][j];
        }
    }

}

template quant_mse(m,n) {
    signal input R_q[m][n];
    signal output out;
    signal intermediate[m*n+1];
    signal input z_R;
    signal input z_Sq;
    signal input sR2sSq_numerator;
    signal input sR2sSq_denominator;
    signal S[4][m][n];

    component div[m][n];

    for (var i = 0; i < m; i++) {
        for (var j = 0; j < n; j++) {
            div[i][j] = Modulo(64);
            S[0][i][j] <== (R_q[i][j] - z_R);
            S[1][i][j] <== S[0][i][j] * S[0][i][j];
            S[2][i][j] <== S[1][i][j] * sR2sSq_numerator;
            div[i][j].dividend <== S[2][i][j];
            div[i][j].divisor <== sR2sSq_denominator;
            S[3][i][j] <== div[i][j].quotient;
        }
    }    

    var k = 0;
    intermediate[0] <== 0;
    for (var i = 0; i < m; i++) {
        for (var j = 0; j < n; j++) {
            intermediate[k+1] <== intermediate[k] + S[3][i][j];
            k = k+1;
    }
    }

    component finaldiv = Modulo(64);
    finaldiv.dividend <== intermediate[m*n];
    finaldiv.divisor <== m * n;

    //log(finaldiv.quotient + z_Sq);
    out <== finaldiv.quotient + z_Sq;

}

template quant_matmul_circuit(m,p,n) {
    signal input X_q[m][p];
    signal private input W_q[p][n];
    signal private input b_q[n];
    signal output out[m][n];
    signal input z_X; 
    signal input z_W;
    signal input z_b;
    signal input z_Y;
    signal input sbsY_numerator;
    signal input sbsY_denominator;
    signal input sXsWsY_numerator;
    signal input sXsWsY_denominator;
    signal b0[n];
    signal b1[n];
    signal b2[n];
    signal mult0[m][n][p+1];
    signal mult1[m][n][p+1];
    signal mult2[m][n][p+1];
    signal mult3[m][n];
    signal mult4[m][n];
    signal mult5[m][n];
    signal m2;

    for (var i0 = 0; i0 < n; i0++) {
        b0[i0] <== (b_q[i0] - z_b) * sbsY_numerator ;
        //log(b0[i0]);
    }

    component bias_div[n];

    for (var i = 0; i < n; i++) {
        bias_div[i] = Modulo(64);
        bias_div[i].dividend <== b0[i];
        bias_div[i].divisor <== sbsY_denominator;
        b1[i] <== bias_div[i].quotient;
        //log(b1[i]);
    }

    for (var i0 = 0; i0 < n; i0++) {
        b2[i0] <== b1[i0] + z_Y;
        //log(b2[i0]);
    }

    for (var i = 0; i < m; i++) {
        for (var j = 0; j < n; j++) {
            mult0[i][j][0] <== 0;
        }
    }

    for (var i = 0; i < m; i++) {
        for (var j = 0; j < n; j++) {
            for (var k = 0; k < p; k++) {
                mult0[i][j][k+1] <== mult0[i][j][k] + (X_q[i][k] * W_q[k][j]);
            }
        }
    }

    for (var i = 0; i < m; i++) {
        for (var j = 0; j < n; j++) {
            mult1[i][j][0] <== mult0[i][j][p];
        }
    }

    
    for (var i = 0; i < m; i++) {
        for (var j = 0; j < n; j++) {
            for (var k = 0; k < p; k++) {
                mult1[i][j][k+1] <== mult1[i][j][k] - z_W * X_q[i][k];
            }
        }
    }

    for (var i = 0; i < m; i++) {
        for (var j = 0; j < n; j++) {
            mult2[i][j][0] <== mult1[i][j][p];
        }
    }

    
    for (var i = 0; i < m; i++) {
        for (var j = 0; j < n; j++) {
            for (var k = 0; k < p; k++) {
                mult2[i][j][k+1] <== mult2[i][j][k] - z_X * W_q[k][j];
            }
        }
    }

    m2 <== z_X * z_W;

    for (var i = 0; i < m; i++) {
        for (var j = 0; j < n; j++) {
            mult3[i][j] <== (mult2[i][j][p] + p*m2) * sXsWsY_numerator;
        }
    }

    component mult_div[m][n];
    
    for (var i = 0; i < m; i++) {
        for (var j = 0; j < n; j++) {
            mult_div[i][j] = Modulo(64);
            mult3[i][j] ==> mult_div[i][j].dividend;
            sXsWsY_denominator ==> mult_div[i][j].divisor;
            mult4[i][j] <== mult_div[i][j].quotient;
        }
    }
    
    for (var i = 0; i < m; i++) {
        for (var j = 0; j < n; j++) {
            mult5[i][j] <== mult4[i][j] + b2[j];
        }
    }

    for (var i = 0; i < m; i++) {
        for (var j = 0; j < n; j++) {
            //log(mult5[i][j]);
            out[i][j] <== mult5[i][j];
        }
    }
    
}

template quant_gemm_mse(m,p,n) {
    signal input X_q[m][p];
    signal private input W_q[p][n];
    signal private input b_q[n];
    signal input z_X; 
    signal input z_W;
    signal input z_b;
    signal input z_Y;
    signal input sbsY_numerator;
    signal input sbsY_denominator;
    signal input sXsWsY_numerator;
    signal input sXsWsY_denominator;
    
    signal input Yt_q[m][n];
    signal input sYsR_numerator;
    signal input sYsR_denominator;
    signal input sYtsR_numerator;
    signal input sYtsR_denominator;
    signal input constant;

    signal input z_R;
    signal input z_Sq;
    signal input sR2sSq_numerator;
    signal input sR2sSq_denominator;

    signal output out;

    component gemm = quant_matmul_circuit(m,p,n);
    component error = quant_error(m,n);
    component mse = quant_mse(m,n);

    for (var i = 0; i < m; i++) {
        for (var j = 0; j < p; j++) {
            X_q[i][j] ==> gemm.X_q[i][j];
        }
    }
    
    for (var i = 0; i < n; i++) {
        b_q[i] ==> gemm.b_q[i];
    }
    
    for (var i = 0; i < p; i++) {
        for (var j = 0; j < n; j++) {
            W_q[i][j] ==> gemm.W_q[i][j];
        }
    }

    z_X ==> gemm.z_X; 
    z_W ==> gemm.z_W;
    z_b ==> gemm.z_b;
    z_Y ==> gemm.z_Y;
    sbsY_numerator ==> gemm.sbsY_numerator;
    sbsY_denominator ==> gemm.sbsY_denominator;
    sXsWsY_numerator ==> gemm.sXsWsY_numerator;
    sXsWsY_denominator ==> gemm.sXsWsY_denominator;


    for (var i = 0; i < m; i++) {
        for (var j = 0; j < n; j++) {
            //log(gemm.out[i][j]);
            gemm.out[i][j] ==> error.Y_q[i][j];
            Yt_q[i][j] ==> error.Yt_q[i][j];
        }
    }

    
    sYsR_numerator ==> error.sYsR_numerator;
    sYsR_denominator ==> error.sYsR_denominator ;
    sYtsR_numerator ==> error.sYtsR_numerator;
    sYtsR_denominator ==> error.sYtsR_denominator;
    constant ==> error.constant;

    for (var i = 0; i < m; i++) {
        for (var j = 0; j < n; j++) {
            //log(error.out[i][j]);
            error.out[i][j] ==> mse.R_q[i][j];
        }
    }

    z_R ==> mse.z_R;
    z_Sq ==> mse.z_Sq;
    sR2sSq_numerator ==> mse.sR2sSq_numerator;
    sR2sSq_denominator ==> mse.sR2sSq_denominator;

    log(mse.out);
    component lt = LessEqThan(64);
    lt.in[0] <== mse.out;
    lt.in[1] <== out;
    lt.out === 1;

}

template quant_gemm_mse_enc(m,p,n) {
    // 0
    signal input hash_input;
    // m * p
    signal input X_q[m][p];
    signal private input W_q[p][n];
    signal private input b_q[n];
    // n * p * 2
    signal input W_q_enc[p][n][2];
    // n * 2
    signal input b_q_enc[n][2];
    signal private input private_key;
    signal input public_key[2];

    /* section total: 8 */
    signal input z_X; 
    signal input z_W;
    signal input z_b;
    signal input z_Y;
    signal input sbsY_numerator;
    signal input sbsY_denominator;
    signal input sXsWsY_numerator;
    signal input sXsWsY_denominator;
    
    signal input Yt_q[m][n];

    /* section total: 5 */
    signal input sYsR_numerator;
    signal input sYsR_denominator;
    signal input sYtsR_numerator;
    signal input sYtsR_denominator;
    signal input constant;

    /* section total: 4 */
    signal input z_R;
    signal input z_Sq;
    signal input sR2sSq_numerator;
    signal input sR2sSq_denominator;

    signal output out;

    component hash = MultiMiMC7(m*p + m*n + 8+5+4, 91);
    hash.k <== 0;

    var idx = 0;
    for (var i = 0; i < m; i++) {
        for (var j = 0; j < p; j++) {
            hash.in[idx] <== X_q[i][j];
            idx = idx + 1;
            
        }
    }

    for (var i = 0; i < m; i++) {
        for (var j = 0; j < n; j++) {
            hash.in[idx] <== Yt_q[i][j];
            idx = idx + 1;
        }
    }

    hash.in[idx] <== z_X;
    idx = idx + 1; 
    hash.in[idx] <== z_W;
    idx = idx + 1;
    hash.in[idx] <== z_b;
    idx = idx + 1;
    hash.in[idx] <== z_Y;
    idx = idx + 1;
    hash.in[idx] <== sbsY_numerator;
    idx = idx + 1;
    hash.in[idx] <== sbsY_denominator;
    idx = idx + 1;
    hash.in[idx] <== sXsWsY_numerator;
    idx = idx + 1;
    hash.in[idx] <== sXsWsY_denominator;
    idx = idx + 1;

    hash.in[idx] <== sYsR_numerator;
    idx = idx + 1;
    hash.in[idx] <== sYsR_denominator;
    idx = idx + 1;
    hash.in[idx] <== sYtsR_numerator;
    idx = idx + 1;
    hash.in[idx] <== sYtsR_denominator;
    idx = idx + 1;
    hash.in[idx] <== constant;
    idx = idx + 1;

    hash.in[idx] <== z_R;
    idx = idx + 1;
    hash.in[idx] <== z_Sq;
    idx = idx + 1;
    hash.in[idx] <== sR2sSq_numerator;
    idx = idx + 1;
    hash.in[idx] <== sR2sSq_denominator;
    idx = idx + 1;

    hash.out === hash_input;

    component gemm = quant_matmul_circuit(m,p,n);
    component error = quant_error(m,n);
    component mse = quant_mse(m,n);

    component ecdh = Ecdh();
    signal shared_key;

    ecdh.private_key <== private_key;
    ecdh.public_key[0] <== public_key[0];
    ecdh.public_key[1] <== public_key[1];

    shared_key <== ecdh.shared_key;

    component weight_enc[p][n];
    component bias_enc[n];
    
    for (var i = 0; i < n; i++) {
        bias_enc[i] = Encrypt();
        bias_enc[i].shared_key <== shared_key;
        bias_enc[i].plaintext <== b_q[i];
        b_q_enc[i][0] === bias_enc[i].out[0];
        b_q_enc[i][1] === bias_enc[i].out[1];
    }


    
    for (var i = 0; i < p; i++) {
        for (var j = 0; j < n; j++) {
            weight_enc[i][j] = Encrypt();
            weight_enc[i][j].shared_key <== shared_key;
            weight_enc[i][j].plaintext <== W_q[i][j];
            W_q_enc[i][j][0] === weight_enc[i][j].out[0];
            W_q_enc[i][j][1] === weight_enc[i][j].out[1];
        }
    }


    for (var i = 0; i < m; i++) {
        for (var j = 0; j < p; j++) {
            X_q[i][j] ==> gemm.X_q[i][j];
        }
    }
    
    for (var i = 0; i < n; i++) {
        b_q[i] ==> gemm.b_q[i];
    }
    
    for (var i = 0; i < p; i++) {
        for (var j = 0; j < n; j++) {
            W_q[i][j] ==> gemm.W_q[i][j];
        }
    }

    z_X ==> gemm.z_X; 
    z_W ==> gemm.z_W;
    z_b ==> gemm.z_b;
    z_Y ==> gemm.z_Y;
    sbsY_numerator ==> gemm.sbsY_numerator;
    sbsY_denominator ==> gemm.sbsY_denominator;
    sXsWsY_numerator ==> gemm.sXsWsY_numerator;
    sXsWsY_denominator ==> gemm.sXsWsY_denominator;


    for (var i = 0; i < m; i++) {
        for (var j = 0; j < n; j++) {
            //log(gemm.out[i][j]);
            gemm.out[i][j] ==> error.Y_q[i][j];
            Yt_q[i][j] ==> error.Yt_q[i][j];
        }
    }

    
    sYsR_numerator ==> error.sYsR_numerator;
    sYsR_denominator ==> error.sYsR_denominator ;
    sYtsR_numerator ==> error.sYtsR_numerator;
    sYtsR_denominator ==> error.sYtsR_denominator;
    constant ==> error.constant;

    for (var i = 0; i < m; i++) {
        for (var j = 0; j < n; j++) {
            //log(error.out[i][j]);
            error.out[i][j] ==> mse.R_q[i][j];
        }
    }

    z_R ==> mse.z_R;
    z_Sq ==> mse.z_Sq;
    sR2sSq_numerator ==> mse.sR2sSq_numerator;
    sR2sSq_denominator ==> mse.sR2sSq_denominator;

    log(mse.out);
    component lt = LessEqThan(64);
    lt.in[0] <== mse.out;
    lt.in[1] <== out;
    lt.out === 1;

}

component main = quant_gemm_mse_enc(20,4,1);