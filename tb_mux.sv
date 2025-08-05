class transaction;
  rand bit a , b , s , rst;
  bit out ;

    function transaction copy();
        copy = new();
        copy.a = this.a;
        copy.b = this.b;
        copy.s = this.s;
        copy.rst = this.rst;
        copy.out = this.out;
    endfunction
    
    function void display(input string tag);
      $display("[%s] A: %0d B:%0d S :%0d RST : %0d OUT : %0d",tag, a , b , s, rst, out);
    endfunction

endclass


class generator;
    transaction tr;
    mailbox mbtodriver;
    mailbox mbtoscore;
    event sconext;
    event done;
    int count;

    function new(mailbox mbtodriver , mailbox mbtoscore);
        this.mbtodriver = mbtodriver;
        this.mbtoscore = mbtoscore;
        tr = new();
    endfunction

    task run();
        repeat(count) begin 
            assert(tr.randomize) else $error("[GEN] Randomization Failure");
            mbtodriver.put(tr.copy);
            mbtoscore.put(tr.copy);
            tr.display("GEN");
            @(sconext);    //waits for scoreboard completion before generating next stimulus
        end
    ->done;
    endtask

endclass


class driver;
    transaction tr;
    mailbox mbtodriver;
    virtual mux_if vif;

  	function new(mailbox mbtodriver);
        this.mbtodriver = mbtodriver;
    endfunction

    task reset();
        vif.rst <= 1'b1;
        #50;
        vif.rst <= 1'b0;
        $display("[DRV] RESET COMPLETE");
    endtask

    task run();
    forever begin
        mbtodriver.get(tr);
        vif.a <= tr.a;
        vif.b <= tr.b;
        vif.s <= tr.s;
        #50;
    end
    endtask

endclass


class monitor;
    transaction tr;
    mailbox mbx;
    virtual mux_if vif;

    function new(mailbox mbx);
        this.mbx = mbx;
    endfunction

    task run();
        forever begin
            tr = new();
            tr.out <= vif.out;
            mbx.put(tr);
            tr.display("MON");
            #20;
        end
    endtask

endclass


class scoreboard;
    transaction tr;
    transaction trref;
    mailbox mbtodriver;
    mailbox mbtoscore;
  	event sconext;

    function new(mailbox mbtodriver, mailbox mbtoscore);
        this.mbtodriver = mbtodriver;
        this.mbtoscore = mbtoscore;
    endfunction

    task run();
        forever begin
            mbtodriver.get(tr);
            mbtoscore.get(trref);
            tr.display("SCO");
            if(tr.out == trref.out)
                $display("DATA MATCHED");
            else 
                $display("DATA MISMATCH !!");
            ->sconext;
        end
    endtask
endclass



class environment;
    generator gen;
    driver drv;
    monitor mon;
    scoreboard sco;
    event next;
    

    mailbox gdmbx;
    mailbox gsmbx;
    mailbox msmbx;

    virtual mux_if vif;

    function new(virtual mux_if vif);
        gdmbx = new();
        gsmbx = new();
        gen = new(gdmbx , gsmbx);
        drv = new(gdmbx);
        msmbx = new();
        mon = new(msmbx);
        sco = new(msmbx ,gsmbx );
        this.vif = vif;
        drv.vif = this.vif;
        mon.vif = this.vif;
        gen.sconext = next;
        sco.sconext = next;
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


module tb();

    mux_if vif();
    mux dut(.a(vif.a), .b(vif.b), .s(vif.s), .rst(vif.rst), .out(vif.out));

    environment env;

    initial begin
        env = new(vif);
        env.gen.count = 12;
        env.run();
    end

    initial begin    
        $dumpfile("dump.vcd");
        $dumpvars;
    end
endmodule



