# SPI
<p>
    <a href=".">
      <img src="https://img.shields.io/badge/RTL%20dev-in%20progress-silver?style=flat-square">
    </a>
    <a href=".">
      <img src="https://img.shields.io/badge/VCS%20sim-no%20start-wheat?style=flat-square">
    </a>
    <a href=".">
      <img src="https://img.shields.io/badge/FPGA%20verif-no%20start-wheat?style=flat-square">
    </a>
    <a href=".">
      <img src="https://img.shields.io/badge/Tapeout%20test-no%20start-wheat?style=flat-square">
    </a>
</p>

## Features
* Compatible with Motorola SPI standard
* Standard SPI mode only
* Max 4 slave device select
* Programmable prescaler
    * max division factor is up to 2^16
* MSB or LSB bit transmission order
* Hardware or Software NSS configuration
* 8, 16, 24 or 32 bits data transmission size
* All CPOL and CPHA mode support
* Independent send and receive FIFO
    * 16~64 data depth
    * empty or no-emtpy status flag
* Maskable send or receive interrupt
* Static synchronous design
* Full synthesizable

## Build and Test
```bash
make comp    # compile code with vcs
make run     # compile and run test with vcs
make wave    # open fsdb format waveform with verdi
```