`timescale 1ns / 100ps

module myuart_reg_tb;
	
	reg clk_100m;
	
	reg 	    pclk;   // 25MHz
	reg 	    preset_n;
	reg 	    psel;
	reg 	    pwrite;
	reg 	    penable;
	reg [5:0]   paddr;
	reg [31:0]  pwdata;
	wire [31:0] prdata;
	
	wire shoot_tx;
	wire [7:0] data_tx;
	reg  busy_tx;
	reg  datarx_vld;
	reg  [7:0] data_rx;
	reg  busy_rx;
	reg  int_parity_error;
	wire interrupt_o;
	wire [3:0]  data_bit_num;
	wire [1:0]  parity_type;
	wire [1:0]  stop_bit_num;
	wire [15:0] divisor;
	wire [7:0]  oversample_rate;
	
	myuart_reg
	#(
	  .CR_OFFSET   				(8'h04),
	  .THR_OFFSET  				(8'h08),
	  .RHR_OFFSET  				(8'h08),
	  .SR_OFFSET   				(8'h0C),
	  .BRGR_OFFSET 				(8'h10),
	  .IMR_OFFSET  				(8'h14)
	)
	u_myuart_reg
	(
	  .pclk_i					(pclk),
	  .preset_n_i				(preset_n),
	  .psel_i					(psel),
	  .pwrite_i					(pwrite),
	  .penable_i				(penable),
	  .paddr_i					(paddr),
	  .pwdata_i					(pwdata),
	  .prdata_o					(prdata),
	  //100MHz
	  .clk_i					(clk_100m),		
	  // for UART TX
	  .shoot_o					(shoot_tx),
	  .datatx_o					(data_tx),
	  .busytx_i					(busy_tx),
	  // for UART RX
	  .datarx_vld_i				(datarx_vld),
	  .datarx_i					(data_rx),
	  .busyrx_i					(busy_rx),
	  .int_parity_error_i		(int_parity_error),
	  // for previous stage
	  .interrupt_o				(interrupt_o),
	  
	  .data_bit_num_o			(data_bit_num),
	  .parity_type_o			(parity_type),
	  .stop_bit_num_o			(stop_bit_num),
	  .divisor_o				(divisor),
	  .oversample_rate_o		(oversample_rate)
	);
	
	localparam CLK_FREQUENCY = 100_000_000;
	localparam HALF_PERIOD = 5;
	localparam APB_HALF_PERIOD = 20;
	localparam FULL_PERIOD = 10;
	localparam APB_FULL_PERIOD = 40;
	localparam BAUD_RATE = 115200;
	localparam BAUD_PERIOD = CLK_FREQUENCY * FULL_PERIOD / BAUD_RATE;
	
	localparam CR_OFFSET   = 8'h04;
	localparam THR_OFFSET  = 8'h08;
	localparam RHR_OFFSET  = 8'h08;
	localparam SR_OFFSET   = 8'h0C;
	localparam BRGR_OFFSET = 8'h10;
	localparam IMR_OFFSET  = 8'h14;
	
	localparam CR_TEMP = 32'h00000272;
	localparam BRGR_TEMP = 32'h00103E01;
	localparam IMR_TEMP = 32'h03;
	localparam THR_TEMP = 32'b10000011;
	
	initial
	begin
		clk_100m = 1'b1;
		forever #HALF_PERIOD clk_100m = ~clk_100m;
	end
	
	initial
	begin
		pclk = 1'b1;
		forever #APB_HALF_PERIOD pclk = ~pclk;
	end
	
	// reset -> CR -> BRGR -> IMR -> THR -> RHR
	initial
	begin
		preset_n = 1'b1;
		#( APB_FULL_PERIOD * 2 )
		preset_n = 1'b0;
		#( APB_FULL_PERIOD * 1 )
		preset_n = 1'b1;
	end
	
	initial
	begin
		busy_rx = 1'b0;
		busy_tx = 1'b0;
		data_rx = 8'b0;
		datarx_vld = 1'b0;
		int_parity_error = 1'b0;
		
		psel = 1'b0;
		penable = 1'b0;
		pwrite = 1'b0;
		paddr = 6'b0;
		pwdata = 32'b0;
		
		// APB write CR
		#( APB_FULL_PERIOD * 5 )
		paddr = CR_OFFSET;
		@ ( posedge pclk ) pwrite = 1'b1;
		psel = 1'b1;
		pwdata = CR_TEMP;
		#( APB_FULL_PERIOD * 1 )
		penable = 1'b1;
		#( APB_FULL_PERIOD * 1 )
		psel = 1'b0;
		penable = 1'b0;
		
		// APB write BRGR
		#( APB_FULL_PERIOD * 1 )
		paddr = BRGR_OFFSET;
		@ ( posedge pclk ) pwrite = 1'b1;
		psel = 1'b1;
		pwdata = BRGR_TEMP;
		#( APB_FULL_PERIOD * 1 )
		penable = 1'b1;
		#( APB_FULL_PERIOD * 1 )
		psel = 1'b0;
		penable = 1'b0;
		
		// APB write IMR
		#( APB_FULL_PERIOD * 1 )
		paddr = IMR_OFFSET;
		@ ( posedge pclk ) pwrite = 1'b1;
		psel = 1'b1;
		pwdata = IMR_TEMP;
		#( APB_FULL_PERIOD * 1 )
		penable = 1'b1;
		#( APB_FULL_PERIOD * 1 )
		psel = 1'b0;
		penable = 1'b0;
		
		// APB write THR
		#( APB_FULL_PERIOD * 1 )
		paddr = THR_OFFSET;
		@ ( posedge pclk ) pwrite = 1'b1;
		psel = 1'b1;
		pwdata = THR_TEMP;
		#( APB_FULL_PERIOD * 1 )
		penable = 1'b1;
		#( APB_FULL_PERIOD * 1 )
		psel = 1'b0;
		penable = 1'b0;
		
		// UART rx input
		#( FULL_PERIOD * 2 )
		data_rx = 8'b11110000;
		@ ( posedge clk_100m ) datarx_vld = 1'b1;
		#( FULL_PERIOD * 1 )
		@ ( posedge clk_100m ) datarx_vld = 1'b0;
		
		// int_parity_error
		#( FULL_PERIOD * 5 )
		int_parity_error = 1'b1;
		
		// APB read RHR
		#( APB_FULL_PERIOD * 1 )
		paddr = RHR_OFFSET;
		@ ( posedge pclk ) pwrite = 1'b0;
		psel = 1'b1;
		#( APB_FULL_PERIOD * 1 )
		penable = 1'b1;
		#( APB_FULL_PERIOD * 1 )
		psel = 1'b0;
		penable = 1'b0;
	end
	
endmodule