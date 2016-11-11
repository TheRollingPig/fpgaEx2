module myuart
	(
	  input		     pclk_i,
	  input			 preset_n_i,
	  input			 psel_i,
	  input			 pwrite_i,
	  input			 penable_i,
	  input	[5:0]	 paddr_i,
	  input [31:0]	 pwdata_i,
	  output [31:0]  prdata_o,
	  
	  input          clk_i,
	  input 	     uart_rx_i,
	  output		 interrupt_o,
	  output         uart_tx_o
	);
	
	wire clk_en;
	wire clk16_en;
	wire shoot_tx;
	wire [7:0] data_tx;
	wire busy_tx;
	wire datarx_vld;
	wire [7:0] data_rx;
	wire busy_rx;
	wire int_parity_error;
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
	  .pclk_i					(pclk_i),
	  .preset_n_i				(preset_n_i),
	  .psel_i					(psel_i),
	  .pwrite_i					(pwrite_i),
	  .penable_i				(penable_i),
	  .paddr_i					(paddr_i),
	  .pwdata_i					(pwdata_i),
	  .prdata_o					(prdata_o),
	  //100MHz
	  .clk_i					(clk_i),		
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
	
	clk_divider u_clk_divider
	(
	  .divisor_i    		(divisor),
	  .oversample_rate_i	(oversample_rate),
	  
	  .clk_i	    		(clk_i),
	  .reset_n_i			(preset_n_i),
	  .clk_en_o     		(clk_en),
	  .clk16_en_o			(clk16_en)
	);
	
    //baud rate: 115200 start bit: 1 data bits: 8 parity bit: none stop bit: 1
	uart_tx_op u_uart_tx_op
	( 
	  .data_bit_num_i 	(data_bit_num),
	  .parity_type_i  	(parity_type), 
	  .stop_bit_num_i 	(stop_bit_num),
	  
	  .clk_i			(clk_i),
	  .reset_n_i		(preset_n_i),
	  .clk_en_i			(clk_en),
	  .data_tx_i		(data_tx),
	  .shoot_i			(shoot_tx),
	  .uart_tx_o 		(uart_tx_o),
	  .busy_tx_o    	(busy_tx)
	);
	
	//baud rate: 115200 start bit: 1 data bits: 8 parity bit: none stop bit: 1
	uart_rx_op u_uart_rx_op
	(
	  .data_bit_num_i		(data_bit_num),   
	  .parity_type_i		(parity_type),    
	  .stop_bit_num_i		(stop_bit_num),   
	  .oversample_rate_i	(oversample_rate),
	
	  .clk_i				(clk_i),
	  .reset_n_i			(preset_n_i),
	  .clk_sample_i			(clk16_en),
	  .uart_rx_i			(uart_rx_i),
	  .data_rx_o         	(data_rx),
	  .datarx_vld_o		    (datarx_vld),
	  .int_parity_error_o	(int_parity_error),
	  .busy_rx_o            (busy_rx)
	);
	
endmodule

