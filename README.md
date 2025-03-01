# Lotus Router

The Lotus Router is an embedded virtual machine which treats instructions as
DeFi protocol interactions, primarily automated market marker protocols. It does
not take fees, it does not extract rent, it is not upgradeable, it is
permissionless, it is free and open source software. It bears the AGPL-3.0
copy-left license.

Built with experience from the frontier, with solidarity for developers of
sovereignity, and with a love for democratization of knowledge and software.

> Work In Progress, Do Not Use Yet

## Why?

Searchers and Solvers alike employ people like us to repeatedly build the state
of the art in router technolopy.

Searchers and Solvers alike justify secrecy with "alpha decay" and other pseudo-
academic terminology in order to hoarde the cutting edge and the capital which
comes with it.

<br/>

We grow tired of building the same software again and again.

We grow tired of signing NDA after NDA.

We grow tired of repeating ourselves.

<br/>

So we the Researchers and Developers write this software with the intent to
democratize the cutting edge of router technology.

So we the Researchers and Developers write this software with the intent to
liberate the secrets of a parasitic industry.

So we the Researchers and Developers write this software with the intent to
expose the elegant simplicity which hides behind bytecode obfuscators and the
mysticism of our local elites.

## Disclaimer

Multiple organizations may contend that this technology was stolen, or that it
is the subject of trade secrets.

However, we the Researchers and Developers formally declare this software is
developed explicitly on our own time, on our own hardware, with our own
software, and with our own knowledge accumulated from both educational resources
and through our understanding and interpretation of the bytecode which exists on
the public blockchains.

## Implementation Details

Batchable actions:

- [x] Uniswap V2 Swap
- [ ] Uniswap V3 Swap
- [ ] Uniswap V4 Swap
- [x] ERC20 Transfer
- [x] ERC20 TransferFrom
- [x] ERC721 TransferFrom
- [x] ERC6909 Transfer
- [x] ERC6909 TransferFrom
- [x] Wrap WETH
- [x] Unwrap WETH

Other features:

- [x] Unconventional Encoder/Decoder (inspired by bigbrainchad.eth)
- [ ] Transient storage call stack constraints (inspired by bigbrainchad.eth)
- [x] Virtual Machine Style Architecture (inspired by, yes, bigbrainchad.eth)

### Call Diagrams

#### Uniswap V2 Chaining

Chaining Uniswap V2 markets entails iteratively calling pairs, forwarding the
output of one swap into the next pair.

- `Lotus` transfers `TokenA` to `MarketAB`
- `Lotus` calls `swap` on `MarketAB`
  - `MarketAB` swaps and transfers `TokenB` to `MarketBC`
- `Lotus` calls `swap` on `MarketBC`
  - `MarketBC` swaps and transfers `TokenC` to `Lotus`

```mermaid
sequenceDiagram
    Lotus-->>MarketAB: transfer A
    Lotus->>+MarketAB: swap(A, B)
    MarketAB-->>MarketBC: transfer B
    MarketAB->>-Lotus: return
    Lotus->>+MarketBC: swap(B, C)
    MarketBC-->>Lotus: transfer C
    MarketBC->>-Lotus: return
```

#### Uniswap V3 Chaining

Chaining Uniswap V3 markets entails recursively calling pools, settling each
market in its respective callback to the router.

While it is possible to simplify encoding control flow by calling iteratively,
recursion saves `O(n)` calls.

- `Lotus` calls `swap` on `MarketBC`
  - `MarketBC` transfers `TokenC` to `Lotus`
  - `MarketBC` calls back into `Lotus` with `uniswapV3Callback`
    - `Lotus` calls `swap` on `MarketAB`
      - `MarketAB` transfers `TokenB` to `Lotus`
      - `MarketAB` calls back into `Lotus` with `uniswapV3Callback`
        - `Lotus` transfers `TokenA` to `MarketAB`, settling the balances
        - `Lotus` transfers `TokenB` to `MarketBC`, settling the balances

```mermaid
sequenceDiagram
    Lotus->>+MarketBC: swap(B, C)
    MarketBC-->>Lotus: transfer C
    MarketBC->>+Lotus: uniswapV3SwapCallback
    Lotus->>+MarketAB: swap(A, B)
    MarketAB-->>Lotus: transfer B
    MarketAB->>+Lotus: uniswapV3SwapCallback
    Lotus-->>MarketAB: transfer A
    Lotus-->>MarketBC: transfer B
    Lotus->>-MarketAB: return
    MarketAB->>-Lotus: return
    Lotus->>-MarketBC: return
    MarketBC->>-Lotus: return
```

A broken out, more intuitive diagram breaks the `Lotus` router out into its
three independent call contexts.

```mermaid
sequenceDiagram
    Lotus->>+MarketBC: swap(B, C)
    MarketBC-->>Lotus(1): transfer C
    MarketBC->>+Lotus(1): uniswapV3SwapCallback
    Lotus(1)->>+MarketAB: swap(A, B)
    MarketAB-->>Lotus(2): transfer B
    MarketAB->>+Lotus(2): uniswapV3SwapCallback
    Lotus(2)-->>MarketAB: transfer A
    Lotus(2)-->>MarketBC: transfer B
    Lotus(2)->>-MarketAB: return
    MarketAB->>-Lotus(1): return
    Lotus(1)->>-MarketBC: return
    MarketBC->>-Lotus: return
```
