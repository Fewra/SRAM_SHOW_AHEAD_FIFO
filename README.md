# SRAM-based Show-Ahead FIFO

A SystemVerilog implementation of a show-ahead FIFO built on top of a simple dual-port SRAM with a fixed read latency of 5 clock cycles.

The design hides SRAM latency using:
- an output prefetch buffer;
- pipelined read requests;
- tracking of outstanding SRAM reads;
- a bypass path for low-latency data forwarding.

## Project structure

```text
rtl/
├── fifo_dualport_with_pipelined_sram.sv
├── sram_dualport_latency_5.sv
└── bram_fifo.sv

tb/
└── fifo_tb.sv
```

## Features

- Show-ahead FIFO interface
- Dual-port SRAM backend
- 5-cycle SRAM read latency
- Prefetching to hide memory latency
- Simultaneous read/write support
- Parameterizable data width and memory depth
- SystemVerilog implementation

## Simulation

The design can be simulated using Vivado/XSim or another SystemVerilog-compatible simulator.

## Purpose

This project was created as an RTL design exercise to practice FIFO architecture, SRAM latency handling, buffering, pipelining, and flow control.