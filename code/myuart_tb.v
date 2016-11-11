`timescale 1ns / 100ps

module myuart_tb;
	
	reg 		clk_100m;
	reg 	    pclk;   // 25MHz
	reg 	    preset_n;
	reg 	    psel;
	reg 	    pwrite;
	reg 	    penable;
	reg [5:0]   paddr;
	reg [31:0]  pwdata;
	wire [31:0] prdata;
	reg 		uart_rx;
	wire		uart_tx;
	wire		interrupt;
	
	integer i;
	
	reg [9:0] rx_data_1 = 10'b0101010101;
	reg [9:0] rx_data_2 = 10'b0111100001;
	reg [9:0] rx_data_3 = 10'b0100000111;
	
	myuart u_myuart
	(
	  .pclk_i			(pclk),
	  .preset_n_i		(preset_n),
	  .psel_i			(psel),
	  .pwrite_i			(pwrite),
	  .penable_i		(penable),
	  .paddr_i			(paddr),
	  .pwdata_i			(pwdata),
	  .prdata_o			(prdata),
	  
	  .clk_i			(clk_100m),
	  .uart_rx_i		(uart_rx),
	  .interrupt_o		(interrupt),
	  .uart_tx_o		(uart_tx)
	);
	
	localparam CLK_FREQUENCY = 100_000_000;
	localparam HALF_PERIOD = 5;
	localparam APB_HALF_PERIOD = 20;
	localparam FULL_PERIOD = 10;
	localparam APB_FULL_PERIOD = 40;
	localparam BAUD_RATE = 115200;
	localparam BAUD_PERIOD = CLK_FREQUENCY * FULL_PERIOD / BAUD_RATE;
	localparam FRAME_BIT_NUM = 10;
	
	localparam CR_OFFSET   = 8'h04;
	localparam THR_OFFSET  = 8'h08;
	localparam RHR_OFFSET  = 8'h08;
	localparam SR_OFFSET   = 8'h0C;
	localparam BRGR_OFFSET = 8'h10;
	localparam IMR_OFFSET  = 8'h14;
	
	// UART_SR UART_IMR
	localparam RXRDY_POS   = 0;
	localparam TXRDY_POS   = 1;
	localparam TXEMPTY_POS = 2;
	localparam PARE_POS    = 5;
	
	localparam CR_TEMP = 32'h00000272;
	localparam BRGR_TEMP = 32'h00103E01;
	localparam IMR_TEMP = 32'h05;
	localparam THR_TEMP = 32'b10010011;
	
	/* 
	drawbacks: 
	1. MCU写THR只能写一次，再根据TXEMPTY来执行下一次写操作，无法连续执行写操作，需要fifo来缓冲数据
	2. 
	*/
	
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
	
	initial
	begin
		preset_n = 1'b1;
		#( APB_FULL_PERIOD * 2 )
		preset_n = 1'b0;
		#( APB_FULL_PERIOD * 1 )
		preset_n = 1'b1;
	end
	
	// register initialize
	initial
	begin
		psel = 1'b0;
		penable = 1'b0;
		pwrite = 1'b0;
		paddr = 6'b0;
		pwdata = 32'b0;
		uart_rx = 1'b1;
		
		// APB write IMR
		#( APB_FULL_PERIOD * 5 )
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
		
		#( APB_FULL_PERIOD * 1 );
		while ( !interrupt )
		begin
			#( APB_FULL_PERIOD * 1 );
		end
		
		// APB write SR clear
		#( APB_FULL_PERIOD * 1 )
		paddr = SR_OFFSET;
		@ ( posedge pclk ) pwrite = 1'b1;
		psel = 1'b1;
		pwdata = 32'b1;
		#( APB_FULL_PERIOD * 1 )
		penable = 1'b1;
		#( APB_FULL_PERIOD * 1 )
		psel = 1'b0;
		penable = 1'b0;
		
		// APB read SR
		/* #( APB_FULL_PERIOD * 1 )
		paddr = SR_OFFSET;
		@ ( posedge pclk ) pwrite = 1'b0;
		psel = 1'b1;
		#( APB_FULL_PERIOD * 1 )
		penable = 1'b1;
		#( APB_FULL_PERIOD * 1 )
		psel = 1'b0;
		penable = 1'b0; */
		
		// RX operation
		#( BAUD_PERIOD * 3 );
		for( i = 0; i < FRAME_BIT_NUM; i = i + 1 )
		begin
			uart_rx = rx_data_1[9 - i];
			#BAUD_PERIOD;
		end
		
		while ( !interrupt )
		begin
			#( APB_FULL_PERIOD * 1 );
		end
		
		// APB read SR
		/* #( APB_FULL_PERIOD * 1 )
		paddr = SR_OFFSET;
		@ ( posedge pclk ) pwrite = 1'b0;
		psel = 1'b1;
		#( APB_FULL_PERIOD * 1 )
		penable = 1'b1;
		#( APB_FULL_PERIOD * 1 )
		psel = 1'b0;
		penable = 1'b0; */
		
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