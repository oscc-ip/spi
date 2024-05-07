## Datasheet

### Overview
The `spi(serial peripheral interface)` IP is a fully parameterised soft IP to implement the Motorola SPI standard protocol. The IP features an APB4 slave interface, fully compliant with the AMBA APB Protocol Specification v2.0.

### Feature
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

* SPM: spi mode
    * `SPM = 2'b00`: std spi mode
    * `SPM = 2'b01`: dual spi mode
    * `SPM = 2'b10`: quad spi mode
    * `SPM = 2'b11`: qpi mode

* RXTH: receive fifo interrupt threshold

* TXTH: transmit fifo interrupt threshold

* RDTB: size of single receive data
    * `RDTB = 2'b00`: 8-bit
    * `RDTB = 2'b01`: 16-bit
    * `RDTB = 2'b10`: 24-bit
    * `RDTB = 2'b11`: 32-bit

* TDTB: size of single transmit data
    * `TDTB = 2'b00`: 8-bit
    * `TDTB = 2'b01`: 16-bit
    * `TDTB = 2'b10`: 24-bit
    * `TDTB = 2'b11`: 32-bit

* SSTR: slave select transmit receive(no use)
    * `SSTR = 1'b0`: spi master mode
    * `SSTR = 1'b1`: spi slave mode

* RDM: reverse data mode
    * `RDM = 1'b0`: normal read data
    * `RDM = 1'b1`: byte-reverse of read data

* ASS: automate slave select
    * `ASS = 1'b0`: software slave select
    * `ASS = 1'b1`: hardware slave select

* LSB: serial send the LSB first
    * `LSB = 1'b0`: send MSB first
    * `LSB = 1'b1`: send LSB first

* CPOL: clock polarity
    * `CPOL = 1'b0`: idle clock is high
    * `CPOL = 1'b1`: idle clock is low

* CPHA: clock phase
    * `CPHA = 1'b0`: sample along the first clock edge
    * `CPHA = 1'b1`: sample along the second clock edge

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


* SNM:

* CSV: 4-bit chip select reverse

* NSS: 4-bit software slave select

* RWM:

* ST: start transmit
    * `ST = 1'b0`: dont transmit data
    * `ST = 1'b1`: otherwise

* EN: spi core enable
    * `EN = 1'b0`: enable spi core
    * `EN = 1'b1`: otherwise

* RXIE: receive interrupt enable
    * `RXIE = 1'b0`: disable receieve interrupt
    * `RXIE = 1'b1`: otherwise

* TXIE: transmit interrupt enable
    * `TXIE = 1'b0`: disable transmit interrupt
    * `TXIE = 1'b1`: otherwise

#### Divide Reigster
| bit | access  | description |
|:---:|:-------:| :---------: |
| `[31:16]` | none | reserved |
| `[15:0]` | RW | DIV |

reset value: `0x000_0000`

* DIV: 16-bit clock division value

#### Command Address Length Reigster
| bit | access  | description |
|:---:|:-------:| :---------: |
| `[31:16]` | none | reserved |
| `[15:0]` | WO | CAL |

reset value: `0x0000_0000`

* CAL: command address transmit length

#### Transmit Receive Length Reigster
| bit | access  | description |
|:---:|:-------:| :---------: |
| `[31:16]` | none | reserved |
| `[15:0]` | WO | TRL |

reset value: `0x0000_0000`

* TRL: transmit receive length

#### Transmit Register
| bit | access  | description |
|:---:|:-------:| :---------: |
| `[31:0]` | WO | TXDATA |

reset value: `none`

* TXDATA: transmit data

#### Receive Register
| bit | access  | description |
|:---:|:-------:| :---------: |
| `[31:0]` | RO | RXDATA |

reset value: `0x0000_0000`

* RXDTA: receive data

#### State Register
| bit | access  | description |
|:---:|:-------:| :---------: |
| `[31:5]` | none | reserved |
| `[4:4]` | RO | RETY |
| `[3:3]` | RO | TFUL |
| `[2:2]` | RO | BUSY |
| `[1:1]` | RO | RXIF |
| `[0:0]` | RO | TXIF |

reset value: `0x0000_0000`

* RETY: receive fifo empty
    * `RETY = 1'b0`: receive fifo is not empty
    * `RETY = 1'b1`: otherwise

* TFUL: transmit fifo full
    * `TFUL = 1'b0`: transmit fifo is not full
    * `TFUL = 1'b1`: otherwise

* BUSY: transmit busy
    * `BUSY = 1'b0`: transmit in progress
    * `BUSY = 1'b1`: otherwise

* RXIF: receive interrupt flag
    * `RXIF = 1'b0`: dont trigger receive interrupt
    * `RXIF = 1'b1`: otherwise

* TXIF: transmit interrupt flag
    * `RXIF = 1'b0`: dont trigger transmit interrupt
    * `RXIF = 1'b1`: otherwise

### Program Guide
These registers can be accessed by 4-byte aligned read and write. C-like pseudocode standard spi write operation to w25q128 nor flash:
```c
// mode 0(CPOL = 0 CPHA = 0)
spi.DIV = DIV_32_bit           // set clock division
spi.CTRL1.ASS = 1              // hardware slave select mode
spi.CTRL2.NSS[0] = 1           // use the one slave select bit
spi.CTRL2.EN = 0               // clear fifo
spi.CTRL2.EN = 1               // enter in normal mode
spi.TXR = 0x06                 // set write enable command
spi.CTRL2.[NSS[0], ST, EN] = 1 // start transmit
...
spi.CTRL1.ASS = 1
spi.CTRL1.[RDTB, TDTB] = 3     // set transmit block size to 32-bit
spi.TXR = 0x02                 // set page program command

for (int i = 0; i < WRITE_DATA_NUM; ++i)
    spi.TXR = WRITE_VALUE

spi.CAL = 0
spi.TRL = WRITE_DATA_NUM + 1
spi.CTRL2.[NSS[0], ST, EN] = 1 // start transmit

```

read operation:
```c
spi.TXR = 0x03                       // set read command
spi.CAL = WRITE_DATA_NUM
spi.TRL = WRITE_DATA_NUM + 1
spi.CTRL2.[NSS[0], RWM, ST, EN] = 1  // start read data

for (int i = 0; i < WRITE_DATA_NUM; ++i)
    uint32_t recv_val = spi.RXR

```

### Resoureces
### References
### Revision History