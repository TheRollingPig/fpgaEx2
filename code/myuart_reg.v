module myuart_reg
	#(
	  parameter CR_OFFSET   = 8'h04,
	  parameter THR_OFFSET  = 8'h08,
	  parameter RHR_OFFSET  = 8'h08,
	  parameter SR_OFFSET   = 8'h0C,
	  parameter BRGR_OFFSET = 8'h10,
	  parameter IMR_OFFSET  = 8'h14
	)
	(
	  input		         pclk_i,
	  input			     preset_n_i,
	  input			     psel_i,
	  input			     pwrite_i,
	  input			     penable_i,
	  input	[5:0]	     paddr_i,
	  input [31:0]	     pwdata_i,
	  output reg [31:0]  prdata_o,
	  
	  input			 	 clk_i,		//100MHz
	  // for UART TX
	  output reg	 	 shoot_o,
	  output reg [7:0]	 datatx_o,
	  input          	 busytx_i,
	  // for UART RX
	  input			 	 datarx_vld_i,
	  input  [7:0]   	 datarx_i,
	  input          	 busyrx_i,
	  input          	 int_parity_error_i,
	  // for previous stage
	  output		 	 interrupt_o,
	  
	  output [3:0]   	 data_bit_num_o,
	  output [1:0]   	 parity_type_o,
	  output [1:0]   	 stop_bit_num_o,
	  output [15:0]  	 divisor_o,
	  output [7:0]   	 oversample_rate_o
	);
	
	// UART_CR
	localparam ENABLE_POS	   = 0;
	localparam PARITY_TYPE_POS = 1;
	localparam PARITY_NONE     = 2'b00;
	localparam PARITY_EVEN     = 2'b01;
	localparam PARITY_ODD      = 2'b10;
	localparam DATA_NUM_POS = 4;
	localparam DATA_NUM_5   = 4'd5;
	localparam DATA_NUM_6  	= 4'd6;
	localparam DATA_NUM_7  	= 4'd7;
	localparam DATA_NUM_8  	= 4'd8;
	localparam STOP_NUM_POS = 8;
	localparam STOP_NUM_1  	= 2'b00;
	localparam STOP_NUM_15 	= 2'b01;
	localparam STOP_NUM_2  	= 2'b10;
	// UART_BRGR
	localparam DIVISOR_POS      = 0;
	localparam DIVISOR_DEFAULT  = 868; //115200
	localparam OVERSAMP_POS     = 16;
	localparam OVERSAMP_DEFAULT = 16;
	// UART_SR UART_IMR
	localparam RXRDY_POS   = 0;
	localparam TXRDY_POS   = 1;
	localparam TXEMPTY_POS = 2;
	localparam PARE_POS    = 5;
	
	reg [31:0] UART_CR;
	/*
	Control Register
	read/write
	bit 0: enable 
	bit 2,1:   PARITY_TYPE: 00(none) 01(even) 10(odd)
	bit 7,6,5,4: DATA_BIT_NUM: 8 7 6 5
	bit 9,8:   STOP_BIT_NUM: 00(1) 01(1.5) 10(2)
	*/
	reg [31:0] UART_BRGR;
	/*
	Baud Rate Generator Register
	read/write
	bit [15:0]: DIVISOR
		Baud Rate = CLK_100m / DIVISOR
	bit [23:16]: OVERSAMP_RATE
		Over Sample Clock = CLK_100m / ( DIVISOR / OVERSAMP_RATE )
	*/
	reg [7:0]  UART_THR;
	reg [7:0]  UART_RHR;
	reg [31:0] UART_SR;
	/*
	Status Register
	read/write
	bit 0: RXRDY   -> read and datarx_i
	bit 1: TXRDY   -> UART_THR
	bit 2: TXEMPTY -> busyrx_i
	bit 5: PARE (W1C)
	W1C(write one clear)
	*/
	reg [31:0] UART_IMR;
	/*
	Interrupt Mask Register
	read/write
	bit 0: RXRDY
	bit 1: TXRDY
	bit 2: TXEMPTY
	bit 5: PARE
	*/
	
	//reg flag_shoot;
	
	// APB write operation
	always @ ( posedge pclk_i )
	begin
		if( !preset_n_i )
		begin
			 //baud rate: 115200 start bit: 1 data bits: 8 parity bit: none stop bit: 1
			UART_CR <= ( 1'b1 | PARITY_NONE << PARITY_TYPE_POS | DATA_NUM_8 << DATA_NUM_POS | STOP_NUM_1 << STOP_NUM_POS );
			UART_BRGR <= ( DIVISOR_DEFAULT << DIVISOR_POS | OVERSAMP_DEFAULT << OVERSAMP_POS );
			UART_RHR <= 8'b0;
			UART_THR <= 8'b0;
			UART_SR <= ( 32'b1 << TXRDY_POS | 32'b0 << RXRDY_POS | 32'b1 << TXEMPTY_POS | 32'b0 << PARE_POS );
			UART_IMR <= 32'b0;
		end
		else
		begin
			if( pwrite_i && psel_i )
			begin
				case( paddr_i )
				  CR_OFFSET:
					UART_CR <= pwdata_i;
				  BRGR_OFFSET:
					UART_BRGR <= pwdata_i;
				  THR_OFFSET:
				    begin
						UART_THR <= pwdata_i;
						// TXRDY clear
						UART_SR[TXRDY_POS] <= 1'b0;
				    end
				  SR_OFFSET:
				    begin
						if( pwdata_i == 32'b1 )
						begin
							UART_SR <= 32'b0;
						end
					end
				  IMR_OFFSET:
					begin
						UART_IMR <= pwdata_i;
					end
				    
				  default:
					begin
						
					end
				endcase
			end
		end
	end
	
	// APB read operation
	always @ ( * )
	begin
		if( !pwrite_i && psel_i && penable_i )
		begin
			case( paddr_i )
			  CR_OFFSET:
				prdata_o = UART_CR;
			  BRGR_OFFSET:
				prdata_o = UART_BRGR;
			  RHR_OFFSET:
				begin
					prdata_o = UART_RHR;
					UART_SR[RXRDY_POS] = 1'b0;
				end
			  SR_OFFSET:
			    prdata_o = UART_SR;
			  IMR_OFFSET:
			    prdata_o = UART_IMR;
			  default:
				begin
					
				end
			endcase
		end
	end
	
	// for UART_CR UART_BRGR
	assign data_bit_num_o = UART_CR >> DATA_NUM_POS;
	assign parity_type_o  = UART_CR >> PARITY_TYPE_POS;
	assign stop_bit_num_o = UART_CR >> STOP_NUM_POS;
	assign divisor_o      = UART_BRGR >> DIVISOR_POS;
	assign oversample_rate_o = UART_BRGR >> OVERSAMP_POS;
	
	// UART TX data operation
	// for UART_THR datatx_o (pipeline with THR) shoot_o 
	always @ ( posedge clk_i )
	begin
		if( !preset_n_i )
		begin
			datatx_o <= 8'b0;
			shoot_o <= 1'b0;
		end
		else
		begin
			if( UART_SR[TXRDY_POS] == 1'b0 )
			begin
				datatx_o <= UART_THR;
				shoot_o <= 1'b1;
				// TXRDY set
				UART_SR[TXRDY_POS] <= 1'b1;
			end
			else
			begin
				shoot_o <= 1'b0;
			end
		end
	end
	
	/*
	always @ ( posedge clk_i )
	begin
		if( !preset_n_i )
		begin
			shoot_o <= 1'b0;
			flag_shoot <= 1'b0;
		end
		else
		begin
			if( pwrite_i && psel_i && !penable_i && paddr_i == THR_OFFSET )
			begin
				flag_shoot <= 1'b0;
			end
			
			if( pwrite_i && psel_i && penable_i && paddr_i == THR_OFFSET && !flag_shoot )
			begin
				shoot_o <= 1'b1;
				flag_shoot <= 1'b1;
			end
			else
			begin
				shoot_o <= 1'b0;
			end
		end
	end
	*/
	
	// UART RX dta operation
	// for UART_RHR
	always @ ( posedge clk_i )
	begin
		if( datarx_vld_i )
		begin
			UART_RHR <= datarx_i;
			UART_SR[RXRDY_POS] <= 1'b1;
		end
	end
	
	// for UART_SR
	always @ ( * )
	begin
		UART_SR[TXEMPTY_POS] = !busytx_i;
	end
	always @ ( posedge clk_i )
	begin
		if( int_parity_error_i )
		begin
			UART_SR[PARE_POS] = 1'b1;
		end
	end
	
	// for interrupt_o
	assign interrupt_o = ( ( UART_IMR & UART_SR ) == 32'b0 ) ? 1'b0 : 1'b1;
	
endmodule