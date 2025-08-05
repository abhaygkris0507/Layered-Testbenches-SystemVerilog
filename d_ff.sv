// D-Flip Flop Module: Synchronous storage element with reset capability
// This module implements a positive edge-triggered D-FF with asynchronous reset

module dff (dff_if vif);              // Module declaration with interface parameter

  // Synchronous logic block: Triggered on positive clock edge
  always @(posedge vif.clk)           // Sensitivity list - execute when clock rises from 0 to 1
    begin
      // Reset condition check: Asynchronous reset has priority over data
      if (vif.rst == 1'b1)            // Check if reset signal is asserted (active high)
        // Reset state: Clear output regardless of input data
        vif.dout <= 1'b0;             // Non-blocking assignment - set output to 0 during reset
      else
        // Normal operation: Transfer input to output on clock edge
        vif.dout <= vif.din;          // Non-blocking assignment - latch input data to output
    end
  
endmodule

// Interface Definition: Signal bundle for D-Flip Flop connections
// This interface encapsulates all DUT signals for modular connection
interface dff_if;
  logic clk;                          // Clock signal - synchronous timing reference
  logic rst;                          // Reset signal - asynchronous clear control
  logic din;                          // Data input - information to be stored
  logic dout;                         // Data output - stored information from previous clock
  
endinterface