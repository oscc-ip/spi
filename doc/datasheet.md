## Datasheet

### Overview
The `spi(serial peripheral interface)` IP is a fully parameterised soft IP to implement the Motorola SPI standard protocol. The IP features an APB4 slave interface, fully compliant with the AMBA APB Protocol Specification v2.0.

### Feature
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

### Interface
| port name | type        | description          |
|:--------- |:------------|:---------------------|
| apb4      | interface   | apb4 slave interface |
| spi ->    | interface   | spi slave interface |
| `spi.spi_sck_o` | output | spi serial clock output |
| `spi.spi_nss_o` | output | spi slave select output |
| `spi.spi_io_en_o` | output | spi output enable |
| `spi.spi_io_in_i` | input | spi data input |
| `spi.spi_io_out_o` | output | spi data output |
| `spi.irq_o` | output | interrupt output|

### Register

| name | offset  | length | description |
|:----:|:-------:|:-----: | :---------: |
| [CTRL1](#control-1-register) | 0x0 | 4 | control 1 register |
| [CTRL2](#control-2-register) | 0x4 | 4 | control 2 register |
| [DIV](#divide-reigster) | 0x8 | 4 | divide register |
| [CAL](#command-address-length-reigster) | 0xC | 4 |  command address length register |
| [TAL](#transmit-receive-length-reigster) | 0x10 | 4 | transmit receive length reigster |
| [TXR](#transmit-register) | 0x14 | 4 | transmit register |
| [RXR](#receive-register) | 0x18 | 4 | receive register |
| [STAT](#state-register) | 0x1C | 4 | state register |

#### Control 1 Register
| bit | access  | description |
|:---:|:-------:| :---------: |
| `[31:22]` | none | reserved |
| `[21:20]` | RW | SPM |
| `[19:15]` | RW | RXTH |
| `[14:10]` | RW | TXTH |
| `[9:8]` | RW | RDTB |
| `[7:6]` | RW | TDTB |
| `[5:5]` | RW | SSTR |
| `[4:4]` | RW | RDM |
| `[3:3]` | RW | ASS |
| `[2:2]` | RW | LSB |
| `[1:1]` | RW | CPOL |
| `[0:0]` | RW | CPHA |

reset value: `0x0000_0000`

#### Control 2 Register
| bit | access  | description |
|:---:|:-------:| :---------: |
| `[31:17]` | none | reserved |
| `[16:13]` | RW | SNM |
| `[12:9]` | RW | CSV |
| `[8:5]` | RW | NSS |
| `[4:4]` | RW | RWM |
| `[3:3]` | RW | ST |
| `[2:2]` | RW | EN |
| `[1:1]` | RW | RXIE |
| `[0:0]` | RW | TXIE |

#### Divide Reigster
| bit | access  | description |
|:---:|:-------:| :---------: |
| `[31:16]` | none | reserved |
| `[15:0]` | RW | DIV |

reset value: `depend on specific shuttle`


#### Command Address Length Reigster
| bit | access  | description |
|:---:|:-------:| :---------: |
| `[31:16]` | none | reserved |
| `[15:0]` | WO | CAL |

reset value: `depend on specific shuttle`


#### Transmit Receive Length Reigster
| bit | access  | description |
|:---:|:-------:| :---------: |
| `[31:16]` | none | reserved |
| `[15:0]` | WO | TRL |

reset value: `depend on specific shuttle`

#### Transmit Register
| bit | access  | description |
|:---:|:-------:| :---------: |
| `[31:0]` | WO | TXDATA |

#### Receive Register
| bit | access  | description |
|:---:|:-------:| :---------: |
| `[31:0]` | RO | RXDATA |

#### State Register
| bit | access  | description |
|:---:|:-------:| :---------: |
| `[31:5]` | none | reserved |
| `[4:4]` | RO | RETY |
| `[3:3]` | RO | TFUL |
| `[2:2]` | RO | BUSY |
| `[1:1]` | RO | RXIF |
| `[0:0]` | RO | TXIF |



### Program Guide
The software operation of `spi` is simple. These registers can be accessed by 4-byte aligned read and write. C-like pseudocode read operation:
```c
uint32_t val;
val = spi.SYS // read the sys register
val = spi.IDL // read the idl register
val = spi.IDH // read the idh register

```
write operation:
```c
uint32_t val = value_to_be_written;
spi.SYS = val // write the sys register
spi.IDL = val // write the idl register
spi.IDH = val // write the idh register

```

### Resoureces
### References
### Revision History