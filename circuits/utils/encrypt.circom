include "../circomlib/circuits/mimc.circom"
include "./ecdh.circom"

template EncryptBits(N) {
  signal private input plaintext[N];
  signal input shared_key;
  signal output out[N+1];

  component mimc = MultiMiMC7(N, 91);
  for (var i=0; i<N; i++) {
    mimc.in[i] <== plaintext[i];
  }
  mimc.k <== 0;
  out[0] <== mimc.out;

  component hasher[N];
  for(var i=0; i<N; i++) {
    hasher[i] = MiMC7(91);
    hasher[i].x_in <== shared_key;
    hasher[i].k <== out[0] + i;
    out[i+1] <== plaintext[i] + hasher[i].out;
  }
}

template Encrypt() {
  signal private input plaintext;
  signal input shared_key;
  signal output out[2];

  component mimc = MultiMiMC7(1, 91);
  mimc.in[0] <== plaintext;
  mimc.k <== 0;
  out[0] <== mimc.out;

  component hasher;
  hasher = MiMC7(91);
  hasher.x_in <== shared_key;
  hasher.k <== out[0];
  out[1] <== plaintext + hasher.out;
}


template DecryptBits(N) {
  signal input message[N+1];
  signal input shared_key;
  signal output out[N];

  component hasher[N];

  // iv is message[0]
  for(var i=0; i<N; i++) {
    hasher[i] = MiMC7(91);
    hasher[i].x_in <== shared_key;
    hasher[i].k <== message[0] + i;
    out[i] <== message[i+1] - hasher[i].out;
  }
}

template Decrypt() {
  signal input message[2];
  signal input shared_key;
  signal output out;

  component hasher;

  // iv is message[0]
  hasher = MiMC7(91);
  hasher.x_in <== shared_key;
  hasher.k <== message[0];
  out <== message[1] - hasher.out;
}

/*
template Test() {
    signal input message;
    signal input shared_key;
    signal output out;
    signal input private_key;
    signal input public_key[2];

    component ecdh = Ecdh();

    ecdh.private_key <== private_key;
    ecdh.public_key[0] <== public_key[0];
    ecdh.public_key[1] <== public_key[1];

    log(ecdh.shared_key);
    log(shared_key);
    log(private_key);
    log(public_key[0]);
    log(public_key[1]);

    shared_key === ecdh.shared_key;

    component enc = Encrypt();
    component dec = Decrypt();

    message ==> enc.plaintext;
    shared_key ==> enc.shared_key;
    shared_key ==> dec.shared_key;
    enc.out[0] ==> dec.message[0];
    enc.out[1] ==> dec.message[1];

    log(dec.out);
    dec.out === message;
    out <== 1;
}

component main = Test();
*/