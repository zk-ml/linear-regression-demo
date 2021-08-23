# circuits

For your convenience, a sample `input.json` and `public.json` pair is included for sanity test checks. `input.json` is a sample input, `public.json` is public parameters. `yarn dev` or `yarn prod` will create `witness.json` and `verification_key.json`, and print to the console verifying that the proof is generated and verifies properly. circuits / redoing setup.

`yarn` to install deps

## Local builds

1. `yarn dev` regenerates development version after touching circuit files

## Production builds

For production entropy, builder.js uses the date and time currently. Run `yarn prod` to generate.
