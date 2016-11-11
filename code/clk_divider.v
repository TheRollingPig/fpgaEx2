module clk_divider
	(
	  input [15:0] divisor_i,
	  input [7:0]  oversample_rate_i,

	  input clk_i,
	  input reset_n_i,
	  output reg clk_en_o,
	  output reg clk16_en_o
	);
	
	wire [15:0] DIVISOR_16;
	reg  [15:0] clk_dividor1;
	reg  [15:0] clk_dividor2;
	
	assign DIVISOR_16 = divisor_i / oversample_rate_i;
	
	// for clk_en_o
	always @ (posedge clk_i or negedge reset_n_i)
	begin
		if(!reset_n_i)
		begin
			clk_dividor1 <= 16'b0;
			clk_en_o <= 1'b0;
		end
		else
		begin
			if(clk_dividor1 != divisor_i)
			begin
				clk_dividor1 <= clk_dividor1 + 1'b1;
				clk_en_o <= 1'b0;
			end
			else
			begin
				clk_dividor1 <= 6'b0;
				clk_en_o <= 1'b1; 
			end
		end
	end
	
	//for clk16_en_o
	always @ (posedge clk_i or negedge reset_n_i)
	begin
		if(!reset_n_i)
		begin
			clk_dividor2 <= 16'b0;
			clk16_en_o <= 1'b0;
		end
		else
		begin
			if(clk_dividor2 != DIVISOR_16)
			begin
				clk_dividor2 <= clk_dividor2 + 1'b1;
				clk16_en_o <= 1'b0;
			end
			else
			begin
				clk_dividor2 <= 6'b0;
				clk16_en_o <= 1'b1; 
			end
		end
	end
	
	/*
	localparam clk_fre   = 100_000_000;
	localparam acc_width = 16;
	localparam acc_inc   = 
	
	reg [acc_width:0] acc;
	
	always @ ( posedge clk_i )
	begin
		if(!reset_n_i)
		begin
			acc <= 16'b0;
			clk_en_o <= 1'b0;
		end
	end
	*/
	
endmodule