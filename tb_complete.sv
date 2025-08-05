// Transaction Class: Data packet that encapsulates all signals for DUT communication
// This class represents a single test vector containing input and expected output
class transaction;
  rand bit din;    // Random input data bit - the 'rand' keyword makes this randomizable
  bit dout;        // Output data bit - stores the expected or actual output from DUT
  
  // Deep copy function: Creates an exact duplicate of the transaction object
  // This prevents data corruption when multiple components access the same transaction
  function transaction copy();
    copy = new();         // Allocate memory for new transaction object
    copy.din = this.din;  // Copy the input data bit from current object
    copy.dout = this.dout; // Copy the output data bit from current object
  endfunction
  
  // Display function: Formatted printing of transaction contents for debugging
  // Input parameter 'tag' identifies which component is printing the transaction
  function void display(input string tag);
    $display("[%0s] : DIN : %0b DOUT : %0b", tag, din, dout); // Print formatted transaction data
  endfunction
  
endclass

//////////////////////////////////////////////////

// Generator Class: Stimulus generation engine that creates randomized test vectors
// This component generates controlled random stimulus for comprehensive DUT testing
class generator;
  transaction tr;                    // Transaction object instance for stimulus generation
  mailbox #(transaction) mbx;        // Mailbox channel to send stimulus data to driver
  mailbox #(transaction) mbxref;     // Mailbox channel to send reference data to scoreboard
  event sconext;                     // Synchronization event - waits for scoreboard completion
  event done;                        // Completion event - signals when all stimulus generation is finished
  int count;                         // Counter variable - specifies number of test vectors to generate

  // Constructor: Initializes generator with communication channels
  // Parameters: mbx (driver mailbox), mbxref (scoreboard reference mailbox)
  function new(mailbox #(transaction) mbx, mailbox #(transaction) mbxref);
    this.mbx = mbx;         // Assign driver communication mailbox
    this.mbxref = mbxref;   // Assign scoreboard reference mailbox
    tr = new();             // Create new transaction object for stimulus generation
  endfunction
  
  // Main stimulus generation task: Creates and distributes test vectors
  task run();
    repeat(count) begin                                                    // Loop for specified number of test vectors
      assert(tr.randomize) else $error("[GEN] : RANDOMIZATION FAILED");   // Randomize transaction, assert success
      mbx.put(tr.copy);     // Send randomized transaction copy to driver via mailbox
      mbxref.put(tr.copy);  // Send same transaction copy to scoreboard for reference comparison
      tr.display("GEN");    // Display generated transaction with "GEN" tag for debugging
      @(sconext);           // Wait for scoreboard completion event before generating next stimulus
    end
    ->done;                 // Trigger completion event when all stimuli have been generated
  endtask
  
endclass

//////////////////////////////////////////////////////////

// Driver Class: Interface controller that applies stimulus to DUT inputs
// This component receives transactions from generator and drives DUT input pins
class driver;
  transaction tr;                  // Transaction object to receive stimulus data
  mailbox #(transaction) mbx;      // Mailbox channel to receive transactions from generator
  virtual dff_if vif;              // Virtual interface handle - provides access to DUT signal pins
  
  // Constructor: Initializes driver with generator communication channel
  // Parameter: mbx (mailbox for receiving transactions from generator)
  function new(mailbox #(transaction) mbx);
    this.mbx = mbx;                // Assign mailbox for transaction communication
  endfunction
  
  // Reset task: Initializes DUT to known state before testing begins
  task reset();
    vif.rst <= 1'b1;               // Assert reset signal (active high) to reset DUT
    repeat(5) @(posedge vif.clk);  // Wait for 5 positive clock edges while reset is active
    vif.rst <= 1'b0;               // Deassert reset signal to enable normal DUT operation
    @(posedge vif.clk);            // Wait for one additional clock edge after reset release
    $display("[DRV] : RESET DONE"); // Print confirmation message for reset completion
  endtask
  
  // Main driving task: Continuously applies stimulus to DUT inputs
  task run();
    forever begin                  // Infinite loop - runs throughout simulation
      mbx.get(tr);                 // Block until new transaction received from generator
      vif.din <= tr.din;           // Apply transaction input data to DUT data input pin
      @(posedge vif.clk);          // Wait for positive clock edge (setup time for DUT)
      tr.display("DRV");           // Display driven transaction with "DRV" tag
      vif.din <= 1'b0;             // Reset input to 0 (default state between transactions)
      @(posedge vif.clk);          // Wait for another clock edge before next transaction
    end
  endtask
  
endclass

//////////////////////////////////////////////////////

// Monitor Class: Output observer that captures DUT response data
// This component continuously watches DUT outputs and forwards them to scoreboard
class monitor;
  transaction tr;                  // Transaction object to store captured output data
  mailbox #(transaction) mbx;      // Mailbox channel to send captured data to scoreboard
  virtual dff_if vif;              // Virtual interface handle - provides access to DUT signal pins
  
  // Constructor: Initializes monitor with scoreboard communication channel
  // Parameter: mbx (mailbox for sending captured data to scoreboard)
  function new(mailbox #(transaction) mbx);
    this.mbx = mbx;                // Assign mailbox for scoreboard communication
  endfunction
  
  // Main monitoring task: Continuously captures DUT output responses
  task run();
    tr = new();                    // Create new transaction object for data capture
    forever begin                  // Infinite loop - runs throughout simulation
      repeat(2) @(posedge vif.clk); // Wait for 2 positive clock edges (accounts for DFF delay)
      tr.dout = vif.dout;          // Capture current DUT output value
      mbx.put(tr);                 // Send captured data to scoreboard via mailbox
      tr.display("MON");           // Display monitored transaction with "MON" tag
    end
  endtask
  
endclass

////////////////////////////////////////////////////

// Scoreboard Class: Result checker that compares actual vs expected outputs
// This component performs golden reference checking to verify DUT correctness
class scoreboard;
  transaction tr;                    // Transaction object for actual DUT output data
  transaction trref;                 // Transaction object for expected reference data  
  mailbox #(transaction) mbx;        // Mailbox channel to receive actual data from monitor
  mailbox #(transaction) mbxref;     // Mailbox channel to receive reference data from generator
  event sconext;                     // Synchronization event - signals completion to generator

  // Constructor: Initializes scoreboard with communication channels
  // Parameters: mbx (monitor mailbox), mbxref (generator reference mailbox)
  function new(mailbox #(transaction) mbx, mailbox #(transaction) mbxref);
    this.mbx = mbx;                  // Assign mailbox for receiving monitor data
    this.mbxref = mbxref;            // Assign mailbox for receiving reference data
  endfunction
  
  // Main checking task: Continuously compares actual vs expected results
  task run();
    forever begin                    // Infinite loop - runs throughout simulation
      mbx.get(tr);                   // Block until actual output data received from monitor
      mbxref.get(trref);             // Block until reference data received from generator
      tr.display("SCO");             // Display actual transaction with "SCO" tag
      trref.display("REF");          // Display reference transaction with "REF" tag
      if (tr.dout == trref.din)      // Compare actual output with expected input (DFF behavior)
        $display("[SCO] : DATA MATCHED");     // Print success message for passing test
      else
        $display("[SCO] : DATA MISMATCHED");  // Print failure message for failing test
      $display("-------------------------------------------------"); // Print separator line
      ->sconext;                     // Signal completion event to synchronize with generator
    end
  endtask
  
endclass

////////////////////////////////////////////////////////

// Environment Class: Top-level test orchestrator that manages all verification components
// This component instantiates and connects all testbench components for coordinated operation
class environment;
  generator gen;                       // Generator instance - creates stimulus vectors
  driver drv;                          // Driver instance - applies stimulus to DUT
  monitor mon;                         // Monitor instance - captures DUT responses  
  scoreboard sco;                      // Scoreboard instance - checks result correctness
  event next;                          // Synchronization event for generator-scoreboard communication

  mailbox #(transaction) gdmbx;        // Generator-to-Driver mailbox communication channel
  mailbox #(transaction) msmbx;        // Monitor-to-Scoreboard mailbox communication channel  
  mailbox #(transaction) mbxref;       // Generator-to-Scoreboard reference mailbox channel
  
  virtual dff_if vif;                  // Virtual interface handle for DUT access

  // Constructor: Creates and connects all verification components
  // Parameter: vif (virtual interface handle for DUT connection)
  function new(virtual dff_if vif);
    gdmbx = new();                     // Create generator-driver communication mailbox
    mbxref = new();                    // Create generator-scoreboard reference mailbox
    gen = new(gdmbx, mbxref);          // Instantiate generator with both mailbox connections
    drv = new(gdmbx);                  // Instantiate driver with generator mailbox
    msmbx = new();                     // Create monitor-scoreboard communication mailbox
    mon = new(msmbx);                  // Instantiate monitor with scoreboard mailbox
    sco = new(msmbx, mbxref);          // Instantiate scoreboard with monitor and reference mailboxes
    this.vif = vif;                    // Store virtual interface handle
    drv.vif = this.vif;                // Connect driver to DUT interface
    mon.vif = this.vif;                // Connect monitor to DUT interface  
    gen.sconext = next;                // Connect generator to synchronization event
    sco.sconext = next;                // Connect scoreboard to synchronization event
  endfunction
  
  // Pre-test setup: Initializes DUT to known state
  task pre_test();
    drv.reset();                       // Execute driver reset sequence for DUT initialization
  endtask
  
  // Main test execution: Starts all verification components in parallel
  task test();
    fork                               // Start all tasks concurrently using fork-join_any
      gen.run();                       // Start stimulus generation process
      drv.run();                       // Start input driving process
      mon.run();                       // Start output monitoring process  
      sco.run();                       // Start result checking process
    join_any                           // Wait for any one process to complete
  endtask
  
  // Post-test cleanup: Waits for completion and terminates simulation
  task post_test();
    wait(gen.done.triggered);          // Block until generator signals completion of all stimulus
    $finish();                         // Terminate simulation gracefully
  endtask
  
  // Master control task: Executes complete test sequence
  task run();
    pre_test();                        // Execute pre-test initialization
    test();                            // Execute main test with all components
    post_test();                       // Execute post-test cleanup and termination
  endtask
endclass

/////////////////////////////////////////////////////

// Testbench Module: Top-level simulation module that instantiates DUT and test environment  
// This module provides the simulation framework and connects all components
module tb;
  dff_if vif();                        // Instantiate DUT interface - creates signal connections

  dff dut(vif);                        // Instantiate Design Under Test (DUT) with interface connection
  
  // Clock initialization block: Sets up initial clock state
  initial begin
    vif.clk <= 0;                      // Initialize clock signal to 0 at simulation start
  end
  
  // Clock generation: Creates continuous periodic clock signal
  always #10 vif.clk <= ~vif.clk;     // Toggle clock every 10 time units (20ns period = 50MHz)
  
  environment env;                     // Environment instance declaration for test orchestration

  // Main test execution block: Sets up and runs the complete verification
  initial begin
    env = new(vif);                    // Create environment instance with DUT interface connection
    env.gen.count = 30;                // Configure generator to create 30 test vectors
    env.run();                         // Execute complete test sequence (pre_test, test, post_test)
  end
  
  // Waveform dump block: Generates simulation traces for debugging
  initial begin
    $dumpfile("dump.vcd");             // Specify output filename for Value Change Dump file
    $dumpvars;                         // Dump all variables and signals for waveform analysis
  end
endmodule