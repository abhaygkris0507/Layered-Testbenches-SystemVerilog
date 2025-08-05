module mux(a , b , s , rst, out);

input a;
input b ;
input s ;
input rst;
output reg out;


always@(*)begin
    if(rst)
        out = 1'b0; // Reset output to 0 when reset is asserted
    else if(s)
        out = b; // Select input b when s is high
    else
        out = a; // Select input a when s is low
end

endmodule



interface mux_if;
  logic a;                            // Input signal a
  logic b;                            // Input signal b
  logic s;                            // Select signal
  logic rst;                          // Reset signal to control output state
  logic out;                          // Output signal                    
endinterface