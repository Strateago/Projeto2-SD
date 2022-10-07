module InfraRed(
					clk,         //clk 50MHz				
					Signal,        //IR code input
					Data,  //data ready
					//Data_Ready        //decode data output
					);


//=======================================================
//  PARAMETER declarations
//=======================================================
parameter Inicio               = 2'b00;    //always Maior voltage level
parameter Espera           = 2'b01;    //9ms Menor voltage and 4.5 ms Maior voltage
parameter Leia           = 2'b10;    //0.6ms Menor voltage start and with 0.52ms Maior voltage is 0,with 1.66ms Maior voltage is 1, 32bit in sum.

parameter Inicio_Maior_Dur      =  262143;  // data_count    262143*0.02us = 5.24ms, threshold for Leia-----> Inicio
parameter Espera_Menor_Dur      =  230000;  // Inicio_count    230000*0.02us = 4.60ms, threshold for Inicio--------->Espera
parameter Espera_Maior_Dur     =  210000;  // state_count   210000*0.02us = 4.20ms, 4.5-4.2 = 0.3ms < BIT_AVAILABLE_Dur = 0.4ms,threshold for Espera------->Leia
parameter Data_Maior_Dur      =  41500;	 // data_count    41500 *0.02us = 0.83ms, sample time from the posedge of Signal
//parameter BIT_AVAILABLE_Dur  =  20000;   // data_count    20000 *0.02us = 0.4ms,  the sample bit pointer,can inhibit the interference from Signal signal


//=======================================================
//  PORT declarations
//=======================================================
input         clk;        //input clk,50MHz
input         Signal;       //Irda RX output decoded data
//output        Data_Ready; //data ready
output [31:0] Data;       //output data,32bit 


//=======================================================
//  Signal Declarations
//=======================================================
reg    [31:0] Data;                 //data output reg
reg    [17:0] Inicio_count;            //Inicio_count counter works under data_read state
reg           Inicio_count_flag;       //Inicio_count conter flag
//wire          Inicio_count_max;
reg    [17:0] state_count;           //state_count counter works under Espera state
reg           state_count_flag;      //state_count conter flag
reg    [17:0] data_count;            //data_count counter works under data_read state
reg           data_count_flag;       //data_count conter flag
reg     [5:0] bitcount;              //sample bit pointer
reg     [1:0] state;                 //state reg
reg    [31:0] data;                  //data reg
reg    [31:0] data_buf;              //data buf
reg           data_ready;            //data ready flag


//=======================================================
//  Structural coding
//=======================================================	
//assign Data_Ready = data_ready;


//Inicio counter works on clk under Inicio state only
always @(posedge clk) begin
	   if (Inicio_count_flag)    //the counter works when the flag is 1
			 Inicio_count <= Inicio_count + 1'b1;
		else  
			 Inicio_count <= 0;	        //the counter resets when the flag is 0		      		 	
end
//Inicio counter switch when Signal is Menor under Inicio state
always @(posedge clk) begin
	   if ((state == Inicio) && !Signal)
			 Inicio_count_flag <= 1'b1;
		else                           
			 Inicio_count_flag <= 1'b0;		     		 	
end  
//state counter works on clk under Espera state only
always @(posedge clk) begin
	  if (state_count_flag)    //the counter works when the flag is 1
			 state_count <= state_count + 1'b1;
		else  
			 state_count <= 0;	        //the counter resets when the flag is 0		      		 	
end
//state counter switch when Signal is Maior under Espera state
always @(posedge clk) begin
	  if ((state == Espera) && Signal)
			 state_count_flag <= 1'b1;
		else  
			 state_count_flag <= 1'b0;     		 	
end
//data read decode counter based on clk
always @(posedge clk) begin
	  if(data_count_flag)      //the counter works when the flag is 1
			 data_count <= data_count + 1'b1;
		else 
			 data_count <= 1'b0;        //the counter resets when the flag is 0
end
//data counter switch
always @(posedge clk) begin	
	  if ((state == Leia) && Signal)
			 data_count_flag <= 1'b1;  
		else
			 data_count_flag <= 1'b0; 
end
//data reg pointer counter 
always @(posedge clk) begin
	  if (state == Leia)
		begin
			if (data_count == 20000)
					bitcount <= bitcount + 1'b1; //add 1 when Signal posedge
		end   
	  else
	     bitcount <= 6'b0;
end
//state change between Inicio,Espera,DATA_READ according to irda edge or counter
always @(posedge clk) begin 
        case (state)
            Inicio     : if (Inicio_count > Espera_Menor_Dur)  // state chang from Inicio to Espera when detect the negedge and the Menor voltage last for > 4.6ms
                            state <= Espera; 
            Espera : if (state_count > Espera_Maior_Dur)//state change from Espera to Leia when detect the posedge and the Maior voltage last for > 4.2ms
                            state <= Leia;
            Leia : if ((data_count >= Inicio_Maior_Dur) || (bitcount >= 33))
                                    state <= Inicio;
            default  : state <= Inicio; //default
        endcase
end
//data decode base on the value of data_count 	
always @(posedge clk) begin
		if (state == Leia)
		begin
			 if (data_count >= Data_Maior_Dur) //2^15 = 32767*0.02us = 0.64us
			    data[bitcount-1'b1] <= 1'b1;  //>0.52ms  sample the bit 1
		end
		else
			 data <= 0;
end	
//set the data_ready flag 
always @(posedge clk) begin
    if (bitcount == 32)   
		begin
			 if (data[31:24] == ~data[23:16])
			 begin		
					data_buf <= data;     //fetch the value to the databuf from the data reg
				  data_ready <= 1'b1;   //set the data ready flag
			 end	
			 else
				  data_ready <= 1'b0 ;  //data error
		end
		else
		   data_ready <= 1'b0 ;
end
//read data
always @(posedge clk) begin
	  if (data_ready)
	     Data<= data_buf;  //output
end				
endmodule