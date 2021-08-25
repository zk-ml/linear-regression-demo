# gemm.py
import json
import sys
from fractions import Fraction

import numpy as np

P = 21888242871839275222246405745257275088548364400416034343698204186575808495617

ALPHA_Q = 4
BETA_Q = 2 ** 16
LIMIT_DENOM = 2 ** 32

def quantization(x, s, z, alpha_q, beta_q):

    x_q = np.round(1 / s * x + z, decimals=0)
    x_q = np.clip(x_q, a_min=alpha_q, a_max=beta_q)

    return x_q


def quantization_arb(x, s, z):

    x_q = quantization(x, s, z, alpha_q=ALPHA_Q, beta_q=BETA_Q)
    x_q = x_q.astype(np.int64)

    return x_q


def dequantization(x_q, s, z):

    x = s * (x_q - z)
    x = x.astype(np.float128)

    return x


def generate_quantization_constants(alpha, beta, alpha_q, beta_q):

    # Affine quantization mapping
    s = (beta - alpha) / (beta_q - alpha_q)
    z = int((beta * alpha_q - alpha * beta_q) / (beta - alpha))

    return s, z


def generate_quantization_arb_constants(alpha, beta):

    alpha_q = ALPHA_Q
    beta_q = BETA_Q

    s, z = generate_quantization_constants(
        alpha=alpha, beta=beta, alpha_q=alpha_q, beta_q=beta_q
    )

    return s, z


# This function can be encoded as a circom circuit
def quantization_error(Y_q, Yt_q, s_R, z_R, s_Y, z_Y, s_Yt, z_Yt):
    # print(z_Y, z_Yt, z_R)
    sYsR = Fraction(s_Y / s_R).limit_denominator(LIMIT_DENOM)
    sYtsR = Fraction(s_Yt / s_R).limit_denominator(LIMIT_DENOM)

    # print(sYsR)
    # print(sYtsR)
    """
    R_q_true = (
        z_R
        + (s_Y / s_R * Y_q).astype(np.int64)
        - (s_Yt / s_R * Yt_q).astype(np.int64)
        - (z_Y * s_Y / s_R)
        + (z_Yt * s_Yt / s_R)
    )
    """
    R_q = (
        z_R
        + (Y_q * sYsR.numerator // sYsR.denominator).astype(np.int64)
        - (Yt_q * sYtsR.numerator // sYtsR.denominator).astype(np.int64)
        - int(z_Y * s_Y / s_R)
        + int(z_Yt * s_Yt / s_R)
    )
    constant = z_R - int(z_Y * s_Y / s_R) + int(z_Yt * s_Yt / s_R)
    # print(R_q - R_q_true)
    return (
        R_q.astype(np.int64),
        sYsR.numerator,
        sYsR.denominator,
        sYtsR.numerator,
        sYtsR.denominator,
        constant,
    )


def quant_error_circuit(Y_q, Yt_q, s_R, z_R, s_Y, z_Y, s_Yt, z_Yt, m, n):
    # print(z_Y, z_Yt, z_R)
    sYsR = Fraction(s_Y / s_R).limit_denominator(LIMIT_DENOM)
    sYtsR = Fraction(s_Yt / s_R).limit_denominator(LIMIT_DENOM)

    # print(Y_q.shape)
    # print("mxn")
    R_q = np.zeros((m, n)).astype(np.int64)

    constant = z_R - int(z_Y * s_Y / s_R) + int(z_Yt * s_Yt / s_R)

    for i in range(m):
        for j in range(n):
            R_q[i, j] = (
                constant
                + (Y_q[i, j] * sYsR.numerator // sYsR.denominator).astype(np.int64)
                - (Yt_q[i, j] * sYtsR.numerator // sYtsR.denominator).astype(np.int64)
            ).astype(np.int64)

    R_q_true = (
        z_R
        + (Y_q * sYsR.numerator // sYsR.denominator).astype(np.int64)
        - (Yt_q * sYtsR.numerator // sYtsR.denominator).astype(np.int64)
        - int(z_Y * s_Y / s_R)
        + int(z_Yt * s_Yt / s_R)
    )
    #print(R_q - R_q_true)

    return R_q


# This function can be encoded as a circom circuit
def quantization_mean_error(Y_q, Yt_q, s_R, z_R, s_Y, z_Y, s_Yt, z_Yt, m):
    # print(z_Y, z_Yt, z_R)
    sYsR = Fraction(s_Y / s_R).limit_denominator(LIMIT_DENOM)
    sYtsR = Fraction(s_Yt / s_R).limit_denominator(LIMIT_DENOM)

    # print(sYsR)
    # print(sYtsR)
    # R_q_true = z_R + (s_Y / s_R * Y_q).astype(np.int64) - (s_Yt / s_R * Yt_q).astype(np.int64) - (z_Y * s_Y / s_R) + (z_Yt * s_Yt / s_R)
    R_q = (
        z_R
        + (Y_q * sYsR.numerator // sYsR.denominator).astype(np.int64)
        - (Yt_q * sYtsR.numerator // sYtsR.denominator).astype(np.int64)
        - int(z_Y * s_Y / s_R)
        + int(z_Yt * s_Yt / s_R)
    )
    # print(R_q - R_q_true)
    return R_q.astype(np.int64).sum() // m


# This function can be encoded as a circom circuit
def quantization_mean_squared_error(R_q, s_R, s_Sq, z_R, z_Sq, m, n):
    sR2sSq = Fraction((s_R ** 2) / s_Sq).limit_denominator(LIMIT_DENOM)
    # print(sR2sSq)
    S_true = (z_Sq + (s_R ** 2) / s_Sq * np.square(R_q - z_R)).astype(np.int64)
    S = (z_Sq + np.square(R_q - z_R) * sR2sSq.numerator // sR2sSq.denominator).astype(
        np.int64
    )

    # print(S_true, S)
    # print("diff mse", abs(S_true - S).T)
    return S.sum() // (m * n), sR2sSq.numerator, sR2sSq.denominator


def quant_mse(R_q, s_R, s_Sq, z_R, z_Sq, m, n):
    sR2sSq = Fraction((s_R ** 2) / s_Sq).limit_denominator(LIMIT_DENOM)
    # print(sR2sSq)

    S = np.zeros((m, n)).astype(np.int64)

    for i in range(m):
        for j in range(n):
            S[i, j] = (
                (
                    (R_q[i, j] - z_R)
                    * (R_q[i, j] - z_R)
                    * sR2sSq.numerator
                    // sR2sSq.denominator
                ).astype(np.int64)
            ).astype(np.int64)

    # _S = (z_Sq + np.square(R_q - z_R) * sR2sSq.numerator // sR2sSq.denominator).astype(
    #    np.int64
    # )

    # print(S - _S)
    return ((S.sum() // (m * n)).astype(np.int64) + z_Sq).astype(np.int64)


# This function can be encoded as a circom circuit
def quantization_matrix_multiplication_arb(
    X_q, W_q, b_q, s_X, z_X, s_W, z_W, s_b, z_b, s_Y, z_Y
):

    p = W_q.shape[0]
    # print('p', p)
    sbsY = Fraction(s_b / s_Y).limit_denominator(LIMIT_DENOM)
    sXsWsY = Fraction(s_X * s_W / s_Y).limit_denominator(LIMIT_DENOM)

    Y_q_simulated = (
        z_Y
        + (s_b / s_Y * (b_q.astype(np.int64) - z_b)).astype(np.int64)
        + (
            (s_X * s_W / s_Y)
            * (
                np.matmul(X_q.astype(np.int64), W_q.astype(np.int64))
                - z_W * np.sum(X_q.astype(np.int64), axis=1, keepdims=True)
                - z_X * np.sum(W_q.astype(np.int64), axis=0, keepdims=True)
                + p * z_X * z_W
            )
        ).astype(np.int64)
    ).astype(np.int64)

    Y_q_simulated_q = (
        z_Y
        + ((b_q.astype(np.int64) - z_b)).astype(np.int64)
        * sbsY.numerator
        // sbsY.denominator
        + (
            (
                np.matmul(X_q.astype(np.int64), W_q.astype(np.int64))
                - z_W * np.sum(X_q.astype(np.int64), axis=1, keepdims=True)
                - z_X * np.sum(W_q.astype(np.int64), axis=0, keepdims=True)
                + p * z_X * z_W
            )
            * sXsWsY.numerator
            // sXsWsY.denominator
        ).astype(np.int64)
    ).astype(np.int64)

    #print("diff quant matmul: ", abs(Y_q_simulated_q - Y_q_simulated).mean())

    return (
        Y_q_simulated_q,
        sbsY.numerator,
        sbsY.denominator,
        sXsWsY.numerator,
        sXsWsY.denominator,
        p,
    )


def quant_matmul_circuit(
    X_q,
    W_q,
    b_q,
    z_X,
    z_W,
    z_b,
    z_Y,
    m,
    n,
    p,
    sbsY_numerator,
    sbsY_denominator,
    sXsWsY_numerator,
    sXsWsY_denominator,
):
    t = (
        X_q,
        W_q,
        b_q,
        z_X,
        z_W,
        z_b,
        z_Y,
        sbsY_numerator,
        sbsY_denominator,
        sXsWsY_numerator,
        sXsWsY_denominator,
    )

    string = "GEMM Input Type"
    ct = 0
    for i in t:
        if type(i) is not int:
            dim1, dim2 = i.shape

            def det(d):
                if d == m:
                    return "m"
                elif d == n:
                    return "n"
                elif d == p:
                    return "p"
                return str(d)

            string += f" ({det(dim1)},{det(dim2)})"
        else:
            string += f" int{ct}"
            ct += 1
    print(string)

    b0 = b_q.astype(np.int64)
    for i0 in range(n):
        b0[0, i0] = (b0[0, i0] - z_b) * sbsY_numerator // sbsY_denominator + z_Y

    #print(b0 - z_b)
    #print("b0 ", b0)
    # b0 = z_Y
    # b0 += (b_q.astype(np.int64) - z_b).astype(np.int64) * sbsY_numerator // sbsY_denominator
    # print(b0)

    mult0 = np.zeros((m, n))
    X_q, W_q = X_q.astype(np.int64), W_q.astype(np.int64)

    for i1 in range(m):
        for j1 in range(n):
            for k1 in range(p):
                mult0[i1, j1] += X_q[i1][k1] * W_q[k1][j1]

    mult = mult0.astype(np.int64)

    # print(mult.shape, W_q.shape)
    # print(np.sum(W_q.astype(np.int64), axis=0, keepdims=True).shape)

    for i2 in range(m):
        for j2 in range(p):
            for k2 in range(n):
                mult[i2, k2] -= z_W * X_q[i2, j2]

    for i3 in range(m):
        for j3 in range(p):
            for k3 in range(n):
                mult[i3, k3] -= z_X * W_q[j3, k3]

    # print((z_W * np.sum(X_q.astype(np.int64), axis=1, keepdims=True)).shape)
    # mult -= z_W * np.sum(X_q.astype(np.int64), axis=1, keepdims=True)
    # for i3 in range(p):

    #    mult
    # print((z_X * np.sum(W_q.astype(np.int64), axis=0, keepdims=True)).shape)
    # mult -= z_X * np.sum(W_q.astype(np.int64), axis=0, keepdims=True)
    mult += p * z_X * z_W
    mult = mult * sXsWsY_numerator // sXsWsY_denominator

    # print(b0.shape)
    # print(mult.shape)
    for l1 in range(m):
        for l2 in range(n):
            mult[l1, l2] += b0[0, l2]

    return mult

def q_model(m, p, n, 
             alpha_X, beta_X,
             alpha_W, beta_W,
             alpha_b, beta_b,
             alpha_Y, beta_Y,
             alpha_Yt, beta_Yt,
             alpha_R, beta_R,
             alpha_S, beta_S,
             X, W, b, Yt_expected):

    # Set random seed for reproducibility
    random_seed = 0
    np.random.seed(random_seed)

    # X
    s_X, z_X = generate_quantization_arb_constants(alpha=alpha_X, beta=beta_X)
    X_q = quantization_arb(x=X, s=s_X, z=z_X)

    # W
    s_W, z_W = generate_quantization_arb_constants(alpha=alpha_W, beta=beta_W)
    W_q = quantization_arb(x=W, s=s_W, z=z_W)

    # b
    s_b, z_b = generate_quantization_arb_constants(alpha=alpha_b, beta=beta_b)
    b_q = quantization_arb(x=b, s=s_b, z=z_b)

    # Y
    s_Y, z_Y = generate_quantization_arb_constants(alpha=alpha_Y, beta=beta_Y)
    Y_expected = np.matmul(X, W) + b
    Y_q_expected = quantization_arb(x=Y_expected, s=s_Y, z=z_Y)

    # Y_true
    s_Yt, z_Yt = generate_quantization_arb_constants(alpha=alpha_Yt, beta=beta_Yt)
    Yt_q_expected = quantization_arb(x=Yt_expected, s=s_Yt, z=z_Yt)

    # Y_res
    s_R, z_R = generate_quantization_arb_constants(alpha=alpha_R, beta=beta_R)

    # Squared Error
    s_Sq, z_Sq = generate_quantization_arb_constants(alpha=alpha_S, beta=beta_S)

    R = Y_expected - Yt_expected
    Mr = R.mean()
    Sq = (R ** 2).mean()

    Sq_q = quantization_arb(x=Sq, s=s_Sq, z=z_Sq)
    R_q = quantization_arb(x=R, s=s_R, z=z_R)
    Mr_q = quantization_arb(x=Mr, s=s_R, z=z_R)

    (
        Y_q_simulated,
        sbsY_numerator,
        sbsY_denominator,
        sXsWsY_numerator,
        sXsWsY_denominator,
        p,
    ) = quantization_matrix_multiplication_arb(
        X_q=X_q,
        W_q=W_q,
        b_q=b_q,
        s_X=s_X,
        z_X=z_X,
        s_W=s_W,
        z_W=z_W,
        s_b=s_b,
        z_b=z_b,
        s_Y=s_Y,
        z_Y=z_Y,
    )

    # Sanity Check
    _Y_q_simulated = quant_matmul_circuit(
        X_q=X_q,
        W_q=W_q,
        b_q=b_q,
        z_X=z_X,
        z_W=z_W,
        z_b=z_b,
        z_Y=z_Y,
        m=m,
        n=n,
        p=p,
        sbsY_numerator=sbsY_numerator,
        sbsY_denominator=sbsY_denominator,
        sXsWsY_numerator=sXsWsY_numerator,
        sXsWsY_denominator=sXsWsY_denominator,
    )
    assert (Y_q_simulated == _Y_q_simulated).all()
    print("gemm assertion passed")
    #print("_Y_q_simulated", _Y_q_simulated)

    (
        R_q_simulated,
        sYsR_numerator,
        sYsR_denominator,
        sYtsR_numerator,
        sYtsR_denominator,
        constant,
    ) = quantization_error(
        Y_q=Y_q_simulated,
        Yt_q=Yt_q_expected,
        s_R=s_R,
        z_R=z_R,
        s_Y=s_Y,
        z_Y=z_Y,
        s_Yt=s_Yt,
        z_Yt=z_Yt,
    )

    _R_q_simulated = quant_error_circuit(
        Y_q=Y_q_simulated,
        Yt_q=Yt_q_expected,
        s_R=s_R,
        z_R=z_R,
        s_Y=s_Y,
        z_Y=z_Y,
        s_Yt=s_Yt,
        z_Yt=z_Yt,
        m=m,
        n=n,
    )

    assert (_R_q_simulated == R_q_simulated).all()
    print("error assertion passed")
    (
        Sq_q_simulated,
        sR2sSq_numerator,
        sR2sSq_denominator,
    ) = quantization_mean_squared_error(R_q_simulated, s_R, s_Sq, z_R, z_Sq, m, n)

    Mr_q_simulated = quantization_mean_error(
        Y_q=Y_q_simulated,
        Yt_q=Yt_q_expected,
        s_R=s_R,
        z_R=z_R,
        s_Y=s_Y,
        z_Y=z_Y,
        s_Yt=s_Yt,
        z_Yt=z_Yt,
        m=m,
    )

    _Sq_q_simulated = quant_mse(R_q_simulated, s_R, s_Sq, z_R, z_Sq, m, n)

    assert (_Sq_q_simulated == Sq_q_simulated).all(), (_Sq_q_simulated, Sq_q_simulated)
    print("mse assertion passed")

    Mr_simulated = dequantization(Mr_q_simulated, s=s_R, z=z_R)
    Sq_simulated = dequantization(Sq_q_simulated, s=s_Sq, z=z_Sq)
    Y_simulated = dequantization(x_q=Y_q_simulated, s=s_Y, z=z_Y)

    #print("Args")
    #print(sbsY_numerator, sbsY_denominator, sXsWsY_numerator, sXsWsY_denominator)
    #print(sYsR_numerator, sYsR_denominator, sYtsR_numerator, sYtsR_denominator)
    #print(sR2sSq_numerator, sR2sSq_denominator)

    #print("Sq actual ", Sq_q.T)
    #print("Sq computed ", Sq_q_simulated.T)
    #print("R_q actual ", R_q.T)
    #print("R_q computed ", R_q_simulated.T)
    #print("R_q diff ", R_q.T - R_q_simulated.T)
    #print("Mr_q actual ", Mr_q)
    #print("Mr_q computed ", Mr_q_simulated)
    #print("Mean Error actual: ", Mr)
    #print("Mean Error simulated: ", Mr_simulated)
    print("Mean Squared Error actual: ", Sq)
    print("Mean Squared Error simulated: ", Sq_simulated)

    def proc(l):
        import warnings

        def proc_int(x):
            if x < 0:
                warnings.warn("Results are negative, circom may not be happy")
                return P-x
            return int(x)

        if type(l) is int:
            return proc_int(l)
        elif type(l) is float:
            assert False, "cannot be float"
        elif type(l[0]) is int:
            return [proc_int(x) for x in l]

        return [[proc_int(x) for x in j] for j in l]

    data_all = dict(
        out=proc(int(_Sq_q_simulated)),
        sR2sSq_numerator=proc(sR2sSq_numerator),
        sR2sSq_denominator=proc(sR2sSq_denominator),
        z_R=proc(z_R),
        z_Sq=proc(z_Sq),
        Yt_q=proc(Yt_q_expected),
        sYsR_numerator=proc(sYsR_numerator),
        sYsR_denominator=proc(sYsR_denominator),
        sYtsR_numerator=proc(sYtsR_numerator),
        sYtsR_denominator=proc(sYtsR_denominator),
        constant=proc(constant),
        X_q=proc(X_q),
        W_q=proc(W_q),
        b_q=proc(b_q),
        z_X=proc(z_X),
        z_W=proc(z_W),
        z_b=proc(z_b),
        z_Y=proc(z_Y),
        sbsY_numerator=proc(sbsY_numerator),
        sbsY_denominator=proc(sbsY_denominator),
        sXsWsY_numerator=proc(sXsWsY_numerator),
        sXsWsY_denominator=proc(sXsWsY_denominator),
    )

    with open("./quantized_dataset.json", "w") as f:
        json.dump(data_all, f, indent=2)



def main():

    # Set random seed for reproducibility
    random_seed = 0
    np.random.seed(random_seed)

    # Random matrices
    m = 20 # Sample Size
    p = 4  # Feature Dim
    n = 1  # Should be 1 for LR

    # X
    alpha_X = -10.0
    beta_X = 8.0
    s_X, z_X = generate_quantization_arb_constants(alpha=alpha_X, beta=beta_X)
    X = np.random.uniform(low=alpha_X, high=beta_X, size=(m, p)).astype(np.float128)
    X_q = quantization_arb(x=X, s=s_X, z=z_X)

    # W
    alpha_W = -20.0
    beta_W = 10.0
    s_W, z_W = generate_quantization_arb_constants(alpha=alpha_W, beta=beta_W)
    W = np.random.uniform(low=alpha_W, high=beta_W, size=(p, n)).astype(np.float128)
    W_q = quantization_arb(x=W, s=s_W, z=z_W)

    # b
    alpha_b = -5.0
    beta_b = 5.0
    s_b, z_b = generate_quantization_arb_constants(alpha=alpha_b, beta=beta_b)
    b = np.random.uniform(low=alpha_b, high=beta_b, size=(1, n)).astype(np.float128)
    b_q = quantization_arb(x=b, s=s_b, z=z_b)

    # Y
    alpha_Y = -50.0
    beta_Y = 50.0
    s_Y, z_Y = generate_quantization_arb_constants(alpha=alpha_Y, beta=beta_Y)
    Y_expected = np.matmul(X, W) + b
    Y_q_expected = quantization_arb(x=Y_expected, s=s_Y, z=z_Y)

    # Y_true
    alpha_Yt = -200.0
    beta_Yt = 200.0
    s_Yt, z_Yt = generate_quantization_arb_constants(alpha=alpha_Yt, beta=beta_Yt)
    Yt_expected = np.random.uniform(low=alpha_Yt, high=beta_Yt, size=(m, n)).astype(
        np.float128
    )
    Yt_q_expected = quantization_arb(x=Yt_expected, s=s_Yt, z=z_Yt)

    # Y_res
    alpha_R = -5000.0
    beta_R = 5000.0
    s_R, z_R = generate_quantization_arb_constants(alpha=alpha_R, beta=beta_R)

    # Squared Error
    alpha_S = 0
    beta_S = 800000
    s_Sq, z_Sq = generate_quantization_arb_constants(alpha=alpha_S, beta=beta_S)

    R = Y_expected - Yt_expected
    Mr = R.mean()
    Sq = (R ** 2).mean()

    Sq_q = quantization_arb(x=Sq, s=s_Sq, z=z_Sq)
    R_q = quantization_arb(x=R, s=s_R, z=z_R)
    Mr_q = quantization_arb(x=Mr, s=s_R, z=z_R)

    (
        Y_q_simulated,
        sbsY_numerator,
        sbsY_denominator,
        sXsWsY_numerator,
        sXsWsY_denominator,
        p,
    ) = quantization_matrix_multiplication_arb(
        X_q=X_q,
        W_q=W_q,
        b_q=b_q,
        s_X=s_X,
        z_X=z_X,
        s_W=s_W,
        z_W=z_W,
        s_b=s_b,
        z_b=z_b,
        s_Y=s_Y,
        z_Y=z_Y,
    )

    # Sanity Check
    _Y_q_simulated = quant_matmul_circuit(
        X_q=X_q,
        W_q=W_q,
        b_q=b_q,
        z_X=z_X,
        z_W=z_W,
        z_b=z_b,
        z_Y=z_Y,
        m=m,
        n=n,
        p=p,
        sbsY_numerator=sbsY_numerator,
        sbsY_denominator=sbsY_denominator,
        sXsWsY_numerator=sXsWsY_numerator,
        sXsWsY_denominator=sXsWsY_denominator,
    )
    assert (Y_q_simulated == _Y_q_simulated).all()
    print("gemm assertion passed")
    #print("_Y_q_simulated", _Y_q_simulated)

    (
        R_q_simulated,
        sYsR_numerator,
        sYsR_denominator,
        sYtsR_numerator,
        sYtsR_denominator,
        constant,
    ) = quantization_error(
        Y_q=Y_q_simulated,
        Yt_q=Yt_q_expected,
        s_R=s_R,
        z_R=z_R,
        s_Y=s_Y,
        z_Y=z_Y,
        s_Yt=s_Yt,
        z_Yt=z_Yt,
    )

    _R_q_simulated = quant_error_circuit(
        Y_q=Y_q_simulated,
        Yt_q=Yt_q_expected,
        s_R=s_R,
        z_R=z_R,
        s_Y=s_Y,
        z_Y=z_Y,
        s_Yt=s_Yt,
        z_Yt=z_Yt,
        m=m,
        n=n,
    )

    assert (_R_q_simulated == R_q_simulated).all()
    print("error assertion passed")
    (
        Sq_q_simulated,
        sR2sSq_numerator,
        sR2sSq_denominator,
    ) = quantization_mean_squared_error(R_q_simulated, s_R, s_Sq, z_R, z_Sq, m, n)

    Mr_q_simulated = quantization_mean_error(
        Y_q=Y_q_simulated,
        Yt_q=Yt_q_expected,
        s_R=s_R,
        z_R=z_R,
        s_Y=s_Y,
        z_Y=z_Y,
        s_Yt=s_Yt,
        z_Yt=z_Yt,
        m=m,
    )

    _Sq_q_simulated = quant_mse(R_q_simulated, s_R, s_Sq, z_R, z_Sq, m, n)

    assert (_Sq_q_simulated == Sq_q_simulated).all(), (_Sq_q_simulated, Sq_q_simulated)
    print("mse assertion passed")

    Mr_simulated = dequantization(Mr_q_simulated, s=s_R, z=z_R)
    Sq_simulated = dequantization(Sq_q_simulated, s=s_Sq, z=z_Sq)
    Y_simulated = dequantization(x_q=Y_q_simulated, s=s_Y, z=z_Y)

    #print("Args")
    #print(sbsY_numerator, sbsY_denominator, sXsWsY_numerator, sXsWsY_denominator)
    #print(sYsR_numerator, sYsR_denominator, sYtsR_numerator, sYtsR_denominator)
    #print(sR2sSq_numerator, sR2sSq_denominator)

    #print("Sq actual ", Sq_q.T)
    #print("Sq computed ", Sq_q_simulated.T)
    #print("R_q actual ", R_q.T)
    #print("R_q computed ", R_q_simulated.T)
    #print("R_q diff ", R_q.T - R_q_simulated.T)
    #print("Mr_q actual ", Mr_q)
    #print("Mr_q computed ", Mr_q_simulated)
    #print("Mean Error actual: ", Mr)
    #print("Mean Error simulated: ", Mr_simulated)
    print("Mean Squared Error actual: ", Sq)
    print("Mean Squared Error simulated: ", Sq_simulated)

    def proc(l):
        import warnings

        def proc_int(x):
            if x < 0:
                warnings.warn("Results are negative, circom may not be happy")
                return P-x
            return int(x)

        if type(l) is int:
            return proc_int(l)
        elif type(l) is float:
            assert False, "cannot be float"
        elif type(l[0]) is int:
            return [proc_int(x) for x in l]

        return [[proc_int(x) for x in j] for j in l]

    """
    data_gemm = dict(
        out=proc(_Y_q_simulated),
        X_q=proc(X_q),
        W_q=proc(W_q),
        b_q=proc(b_q),
        z_X=proc(z_X),
        z_W=proc(z_W),
        z_b=proc(z_b),
        z_Y=proc(z_Y),
        sbsY_numerator=proc(sbsY_numerator),
        sbsY_denominator=proc(sbsY_denominator),
        sXsWsY_numerator=proc(sXsWsY_numerator),
        sXsWsY_denominator=proc(sXsWsY_denominator),
    )
    print(_Y_q_simulated)

    data_error = dict(
        out=proc(_R_q_simulated),
        Y_q=proc(Y_q_simulated),
        Yt_q=proc(Yt_q_expected),
        sYsR_numerator=proc(sYsR_numerator),
        sYsR_denominator=proc(sYsR_denominator),
        sYtsR_numerator=proc(sYtsR_numerator),
        sYtsR_denominator=proc(sYtsR_denominator),
        constant=proc(constant),
    )
    print(_R_q_simulated)

    data_mse = dict(
        out=proc(int(_Sq_q_simulated)),
        R_q=proc(_R_q_simulated),
        sR2sSq_numerator=proc(sR2sSq_numerator),
        sR2sSq_denominator=proc(sR2sSq_denominator),
        z_R=proc(z_R),
        z_Sq=proc(z_Sq),
    )

    data_interm = dict(
        X_q=proc(X_q),
        W_q=proc(W_q),
        b_q=proc(b_q),
        z_X=proc(z_X),
        z_W=proc(z_W),
        z_b=proc(z_b),
        z_Y=proc(z_Y),
        sbsY_numerator=proc(sbsY_numerator),
        sbsY_denominator=proc(sbsY_denominator),
        sXsWsY_numerator=proc(sXsWsY_numerator),
        sXsWsY_denominator=proc(sXsWsY_denominator),
        out=proc(_R_q_simulated),
        Yt_q=proc(Yt_q_expected),
        sYsR_numerator=proc(sYsR_numerator),
        sYsR_denominator=proc(sYsR_denominator),
        sYtsR_numerator=proc(sYtsR_numerator),
        sYtsR_denominator=proc(sYtsR_denominator),
        constant=proc(constant),
    )
    """

    data_all = dict(
        out=proc(int(_Sq_q_simulated)),
        sR2sSq_numerator=proc(sR2sSq_numerator),
        sR2sSq_denominator=proc(sR2sSq_denominator),
        z_R=proc(z_R),
        z_Sq=proc(z_Sq),
        Yt_q=proc(Yt_q_expected),
        sYsR_numerator=proc(sYsR_numerator),
        sYsR_denominator=proc(sYsR_denominator),
        sYtsR_numerator=proc(sYtsR_numerator),
        sYtsR_denominator=proc(sYtsR_denominator),
        constant=proc(constant),
        X_q=proc(X_q),
        W_q=proc(W_q),
        b_q=proc(b_q),
        z_X=proc(z_X),
        z_W=proc(z_W),
        z_b=proc(z_b),
        z_Y=proc(z_Y),
        sbsY_numerator=proc(sbsY_numerator),
        sbsY_denominator=proc(sbsY_denominator),
        sXsWsY_numerator=proc(sXsWsY_numerator),
        sXsWsY_denominator=proc(sXsWsY_denominator),
    )

    #with open("./artifacts/quantization/inputs_gemm.json", "w") as f:
    #    json.dump(data_gemm, f, indent=2)

    #with open("./artifacts/quantization/inputs_error.json", "w") as f:
    #    json.dump(data_error, f, indent=2)

    #with open("./artifacts/quantization/inputs_mse.json", "w") as f:
    #    json.dump(data_mse, f, indent=2)

    #with open("../../circuits/utils/input.json", "w") as f:
    #    json.dump(data_all, f, indent=2)

    with open("./artifacts/quantization/inputs_dataset.json", "w") as f:
        json.dump(data_all, f, indent=2)

    #with open("./artifacts/quantization/inputs_interm.json", "w") as f:
    #    json.dump(data_interm, f, indent=2)

    #print("diff e ", abs(Y_expected - Y_simulated).mean())
    #print("diff q ", abs(Y_q_expected - Y_q_simulated).mean())

if __name__ == "__main__":

    main()
