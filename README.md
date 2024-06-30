# Trade Contract

## Overview
The Trade contract is designed for trading ERC1155 assets on the Bodhi platform. It enables application developers to build applications on top of Bodhi and set application-specific fees (app fees). This smart contract is developed using Solidity and is compatible with Solidity version 0.8.18.

## Security
This contract is currently in development and has not yet undergone rigorous security audits. It is crucial to ensure that there are no vulnerabilities that could be exploited. We strongly advise against using this contract for trading real assets until it has been thoroughly tested and audited by security professionals.

## Optimism Sepolia Test Contract Addresses

| Contract | Address                                    |
|----------|--------------------------------------------|
| Bodhi    | [0xD4B4386a3632D406E3b8c4EC38486f83E8f8D889](https://sepolia-optimism.etherscan.io/address/0xD4B4386a3632D406E3b8c4EC38486f83E8f8D889) |
| Trade    | [0x1a079cE9D7d6DdeE6774293380Fdd0b2953F7Dd8](https://sepolia-optimism.etherscan.io/address/0x1a079cE9D7d6DdeE6774293380Fdd0b2953F7Dd8) |

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
