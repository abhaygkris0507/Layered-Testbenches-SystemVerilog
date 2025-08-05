class transaction;
    rand bit oper;
    bit full, empty , rd , wr;
    bit [7:0] data_in;
    bit [7:0] data_out;
    
    
constraint oper_ctrl{
    oper dist{1 :/50 , 0:/50};     //50% write and 50% read operation
}


endclass 


class generator;
    transaction tr;
    mailbox #(transaction) mbx;  //mailbox to driver

    int count = 0;   
    int i = 0; 

    event next;
    event done;
    

    function new(mailbox #(transaction) mbx);
        this.mbx = mbx;
        tr=new();
    endfunction

    task run();
        repeat(count) begin   
            assert(tr.randomize) else $error("Randomization failure");
            i++;
            mbx.put(tr);
            $display("[GEN]: Oper: %0d Iteration: %0d ",tr.oper,i);
            @(next);
        end
    ->done;    
    endtask

endclass


class driver;
    virtual fifo_if fif;

    mailbox #(transaction) mbx;

    transaction dc;

    event next;

    function new(mailbox #(transaction) mbx);
        this.mbx = mbx;
    endfunction

    task reset();
        fif.rst <= 1'b1;
        fif.wr <= 1'b0;
        fif.wr <= 1'b0;
        fif.data_in <= 0;
        repeat(5) @(posedge fif.clk);
        $display("[DRV]: Reset Complete");
    endtask

    task write();
        @(posedge fif.clk);
        fif.rst <= 1'b0;
        fif.rd <= 1'b0;
        fif.wr <= 1'b1;
        fif.data_in <= $urandom_range(1,10);
        @(posedge fif.clk);
        fif.wr  <= 1'b0;
        $display("[DRV]: WRITE DATA : %0d",fif.data_in);
        @(posedge fif.clk);
    endtask

    task read();
        @(posedge fif.clk);
        fif.rst <= 1'b0;
        fif.rd <= 1'b1;
        fif.wr <= 1'b0;
        @(posedge fif.clk);
        fif.rd  <= 1'b0;
        $display("[DRV]: READ DATA ");
        @(posedge fif.clk);
    endtask

    task run();
        forever begin
            mbx.get(dc);
            if(dc.oper == 1'b1)
                write();
            else
                read();
        end
    endtask

endclass


class monitor;

    virtual fifo_if fif;
    transaction dc;
    mailbox #(transaction) mbx;

    function new(mailbox #(transaction) mbx);
        this.mbx = mbx;
    endfunction

    task run();
    dc = new();
    forever begin
        repeat(2) @(posedge fif.clk);
        dc.wr = fif.wr;
        dc.rd = fif.rd;
        dc.data_in = fif.data_in;
        dc.full = fif.full;
        dc.empty = fif.empty;
        @(posedge fif.clk);
        dc.data_out = fif.data_out;

        mbx.put(dc);
        $display("[MON]: WR:%0d RD:%0d din: %0d dout: %0d full: %0d empty %0d",dc.wr , dc.rd , dc.data_in,dc.data_out , dc.full , dc.empty);
    end
    endtask

endclass

class scoreboard;
    transaction dc;
    mailbox #(transaction) mbx;
    event next;

    bit [7:0] din[$];
    bit[7:0] temp;
    int err = 0;

    function new(mailbox #(transaction) mbx);
    this.mbx = mbx;
    endfunction

    task run();
    forever begin
      mbx.get(dc);

        $display("[SCO]: WR:%0d RD:%0d din: %0d dout: %0d full: %0d empty %0d",dc.wr , dc.rd , dc.data_in,dc.data_out , dc.full , dc.empty);

      if(dc.wr == 1'b1)
            begin
              if(dc.full == 1'b0)
                begin
                  din.push_front(dc.data_in);
                  $display("[SCO]: DATA STORED IN QUEUE: %0d",dc.data_in);
                end
                else
                begin
                    $display("[SCO]: FIFO IS FULL");
                end
                $display("-------------------------");
            end

      if(dc.rd == 1'b1)
            begin
              if(dc.empty == 1'b0)
                begin
                    temp = din.pop_back();

                  if(dc.data_out == temp)
                    $display("[SCO] DATA MATCH");
                else begin
                    $display("[SCO] DATA MISMATCH");
                    err++;
                end
                end
                else begin
                    $display("[SCO] FIFO IS EMPTY");
                end
            end
            ->next;
    end

    endtask
endclass


class environment;
    generator gen;
    driver drv;
    monitor mon;
    scoreboard sco;
    transaction tr;
    mailbox #(transaction) gdmbx;
    mailbox #(transaction) msmbx;

    event nextgs;

    virtual fifo_if fif;

    function new(virtual fifo_if fif);
        gdmbx = new();
        gen = new(gdmbx);
        drv = new(gdmbx);
        msmbx = new();
        mon = new(msmbx);
        sco = new(msmbx);
        this.fif = fif;
        drv.fif = this.fif;
        mon.fif = this.fif;
        gen.next = nextgs;
        sco.next = nextgs;
    endfunction

    task pre_test();
        drv.reset();
    endtask

    task test();
        fork
            gen.run();
            drv.run();
            mon.run();
            sco.run();
        join_any
    endtask

    task post_test();
        wait(gen.done.triggered)
        $display("Error count : %0d",sco.err);
        $finish();
    endtask
  
  	task run();
    	pre_test();
    	test();
    	post_test();
  	endtask

endclass

module tb;
    fifo_if fif();

    FIFO dut(fif.clk,fif.rst,fif.wr,fif.rd,fif.data_in,fif.data_out,fif.empty,fif.full);

    initial begin
        fif.clk <= 0;
    end

    always #10 fif.clk <= ~fif.clk;

    environment env;

    initial begin
      	env = new(fif);
        env.gen.count = 10;
        env.run();
    end

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars;
    end
endmodule




