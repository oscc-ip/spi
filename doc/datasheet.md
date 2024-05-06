## Datasheet

### Overview
The `spi` IP is a fully parameterised soft IP recording the SoC architecture and ASIC backend informations. The IP features an APB4 slave interface, fully compliant with the AMBA APB Protocol Specification v2.0.

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

### Register

| name | offset  | length | description |
|:----:|:-------:|:-----: | :---------: |
| [SYS](#system-info-register) | 0x0 | 4 | system info register |
| [IDL](#id-low-reigster) | 0x4 | 4 | id low register |
| [IDH](#id-high-reigster) | 0x8 | 4 | id high register |

#### System Info Register
| bit | access  | description |
|:---:|:-------:| :---------: |
| `[31:20]` | none | reserved |
| `[19:8]` | RW | CLOCK |
| `[7:0]` | RW | SRAM |

reset value: `depend on specific shuttle`

* CLOCK: core clock frequency information by using three-bit BCD code
* SRAM: the total size of SRAM, unit: KB. example: `SRAM=128` means 128KB

#### ID Low Reigster
| bit | access  | description |
|:---:|:-------:| :---------: |
| `[31:30]` | RW | TYPE |
| `[29:22]` | RW | VENDOR |
| `[21:6]` | RW | PROCESS |
| `[5:0]` | RW | CUST |

reset value: `depend on specific shuttle`

* TYPE: tape out type 
    * `2'b00`: OSOC (one student one chip)
    * `2'b01`: IEDA (open source eda)
    * `2'b10`: EP (epiboly)
    * `2'b11`: TEST (prototype test)
* VENDOR: asic vendor encoding, the encoding table is currently not publicly open available
* PROCESS: the process of tape out by using 4-bit BCD code, for example, the `0130` means the 130nm process
* CUST: user customized information

#### ID High Reigster
| bit | access  | description |
|:---:|:-------:| :---------: |
| `[31:24]` | none | reserved |
| `[23:0]` | RW | DATE |

reset value: `depend on specific shuttle`

* DATE: the date of tape out by using six-bit BCD code, for example: 202404

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