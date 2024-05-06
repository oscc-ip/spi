# SPI

## Features
* Compatible with Motorola SPI standard
* Half duplex serial data transmission
* SPI master mode only
* Standard, dual and quad SPI mode support
* Max 4 slave device select
* Programmable prescaler
    * max division factor is up to 2^16
* MSB or LSB bit transmission order
* Hardware or Software NSS configuration
* 8, 16, 24 or 32 bits data transmission size
* 1~65536 transmission length with hardware NSS
* All CPOL and CPHA mode support
* Programmable dummay and delay cycles configuration
* Independent send and receive FIFO
    * 16~64 data depth
    * empty or no-emtpy status flag
* Maskable send or receive interrupt and programmable threshold
* Static synchronous design
* Full synthesizable

FULL vision of datatsheet can be found in [datasheet.md](./doc/datasheet.md).

## Build and Test
```bash
make comp    # compile code with vcs
make run     # compile and run test with vcs
make wave    # open fsdb format waveform with verdi
```