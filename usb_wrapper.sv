(* keep_hierarchy = "yes" *)
module usb_wrapper #(
    parameter C_ASIC_SRAM = 0
) (
    input aclk,
    input aresetn,
    AXI_BUS.Slave slv,
    AXI_BUS.Master dma_mst,
    output interrupt,
    
    input  wire       ULPI_clk,
    input  wire [7:0] ULPI_data_i,
    output wire [7:0] ULPI_data_o,
    output wire [7:0] ULPI_data_t,
    output wire       ULPI_stp,
    input  wire       ULPI_dir,
    input  wire       ULPI_nxt
);

logic [31:0]     ahb_haddr;       // ahb bus address
logic [2:0]      ahb_hburst;      // burst
logic [2:0]      ahb_hsize;       // size of bus transaction (possible values 0,1,2,3)
logic [1:0]      ahb_htrans;      // Transaction type (possible values 0,2 only right now)
logic            ahb_hwrite;      // ahb bus write
logic [31:0]     ahb_hwdata;      // ahb bus write data
logic [31:0]     ahb_hrdata;      // ahb bus read data
logic            ahb_hready;      // slave ready to accept transaction
logic [1:0]      ahb_hresp;       // slave response (high indicates erro)

axi_ahblite_bridge conv (
    .s_axi_aclk(aclk),
    .s_axi_aresetn(aresetn),

    .m_ahb_haddr     (ahb_haddr ),
    .m_ahb_hburst    (ahb_hburst),
    .m_ahb_hsize     (ahb_hsize ),
    .m_ahb_htrans    (ahb_htrans),
    .m_ahb_hwrite    (ahb_hwrite),
    .m_ahb_hwdata    (ahb_hwdata),
    .m_ahb_hrdata    (ahb_hrdata),
    .m_ahb_hready    (ahb_hready),
    .m_ahb_hresp     (ahb_hresp[0]),
    
    .s_axi_awid(slv.aw_id),
    .s_axi_awaddr(slv.aw_addr),
    .s_axi_awlen(slv.aw_len),
    .s_axi_awsize(slv.aw_size),
    .s_axi_awburst(slv.aw_burst),
    .s_axi_awcache(4'b0),
    .s_axi_awprot(3'b0),
    .s_axi_awlock(1'b0),
    .s_axi_awvalid(slv.aw_valid),
    .s_axi_awready(slv.aw_ready),
    
    .s_axi_wdata(slv.w_data),
    .s_axi_wstrb(slv.w_strb),
    .s_axi_wlast(slv.w_last),
    .s_axi_wvalid(slv.w_valid),
    .s_axi_wready(slv.w_ready),
    
    .s_axi_bid(slv.b_id),
    .s_axi_bresp(slv.b_resp),
    .s_axi_bvalid(slv.b_valid),
    .s_axi_bready(slv.b_ready),
    
    .s_axi_arid(slv.ar_id),
    .s_axi_araddr(slv.ar_addr),
    .s_axi_arprot(3'b0),
    .s_axi_arcache(4'b0),
    .s_axi_arlock(1'b0),
    .s_axi_arlen(slv.ar_len),
    .s_axi_arsize(slv.ar_size),
    .s_axi_arvalid(slv.ar_valid),
    .s_axi_arburst(slv.ar_burst),
    .s_axi_arready(slv.ar_ready),
    
    .s_axi_rid(slv.r_id),
    .s_axi_rdata(slv.r_data),
    .s_axi_rresp(slv.r_resp),
    .s_axi_rlast(slv.r_last),
    .s_axi_rvalid(slv.r_valid),
    .s_axi_rready(slv.r_ready)
);

wire [34:0] fifo_din, fifo_dout;
wire [11:0] fifo_addr;
wire fifo_ce, fifo_we;

generate if (C_ASIC_SRAM) begin
    S018SP_RAM_SP_W4096_B35_M8 usb_fifo_s (
        .Q(fifo_dout),
        .CLK(aclk),
        .CEN(fifo_ce),
        .WEN(fifo_we),
        .A(fifo_addr),
        .D(fifo_din)
    );
end else begin
    xpm_memory_spram #(
          .ADDR_WIDTH_A($bits(fifo_addr)),              // DECIMAL
          .AUTO_SLEEP_TIME(0),           // DECIMAL
          .BYTE_WRITE_WIDTH_A(35),       // DECIMAL
          .CASCADE_HEIGHT(0),            // DECIMAL
          .ECC_MODE("no_ecc"),           // String
          .MEMORY_INIT_FILE("none"),     // String
          .MEMORY_INIT_PARAM("0"),       // String
          .MEMORY_OPTIMIZATION("true"),  // String
          .MEMORY_PRIMITIVE("auto"),     // String
          .MEMORY_SIZE(35*(1<<$bits(fifo_addr))),            // DECIMAL
          .MESSAGE_CONTROL(0),           // DECIMAL
          .READ_DATA_WIDTH_A(35),        // DECIMAL
          .READ_LATENCY_A(1),            // DECIMAL
          .READ_RESET_VALUE_A("0"),      // String
          .RST_MODE_A("SYNC"),           // String
          .SIM_ASSERT_CHK(0),            // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
          .USE_MEM_INIT(0),              // DECIMAL
          .WAKEUP_TIME("disable_sleep"), // String
          .WRITE_DATA_WIDTH_A(35),       // DECIMAL
          .WRITE_MODE_A("write_first")    // String
       ) usb_fifo (
          .douta(fifo_dout),
          .addra(fifo_addr),
          .clka(aclk),
          .dina(fifo_din),
          .ena(~fifo_ce),
          .injectdbiterra(0),
          .injectsbiterra(0), 
          .regcea(1),
          .rsta(0),
          .sleep(0),
          .wea(~fifo_we)
       );
end
endgenerate

wire [31:0]  dma_haddr;
wire [31:0]  dma_hwdata;
wire [31:0]  dma_hrdata;
wire [3:0]   dma_hprot; 
wire [1:0]   dma_htrans;
wire [2:0]   dma_hsize;
wire [2:0]   dma_hburst;
wire         dma_hwrite;
wire         dma_hready_miso;
wire         dma_hready_mosi;
wire [1:0]   dma_hresp;
assign dma_hresp[1] = 0;

ahblite_axi_bridge mstconv (
    .s_ahb_hclk(aclk),
    .s_ahb_hresetn(aresetn),
    .s_ahb_hsel('1),
      
    .s_ahb_haddr  (dma_haddr   ),
    .s_ahb_hprot  (dma_hprot   ),
    .s_ahb_htrans (dma_htrans  ),
    .s_ahb_hsize  (dma_hsize   ),
    .s_ahb_hburst (dma_hburst  ),
    .s_ahb_hwdata (dma_hwdata  ),
    .s_ahb_hrdata (dma_hrdata  ),
    .s_ahb_hwrite (dma_hwrite  ),
    .s_ahb_hready_out (dma_hready_miso),
    .s_ahb_hready_in  (dma_hready_miso),
    .s_ahb_hresp      (dma_hresp[0]   ),
      
    .m_axi_awready (dma_mst.aw_ready), .m_axi_awaddr (dma_mst.aw_addr),
    .m_axi_awvalid (dma_mst.aw_valid), .m_axi_awid   (dma_mst.aw_id  ),
	.m_axi_awlen   (dma_mst.aw_len  ), .m_axi_awsize (dma_mst.aw_size),
	.m_axi_awburst (dma_mst.aw_burst),
	//
	.m_axi_wready  (dma_mst.w_ready ), .m_axi_wdata  (dma_mst.w_data ),
	.m_axi_wstrb   (dma_mst.w_strb  ), .m_axi_wvalid (dma_mst.w_valid),
	.m_axi_wlast   (dma_mst.w_last  ),
	//
	.m_axi_bresp   (dma_mst.b_resp  ), .m_axi_bid    (dma_mst.b_id   ),
	.m_axi_bvalid  (dma_mst.b_valid ), .m_axi_bready (dma_mst.b_ready),
	//
	.m_axi_arid    (dma_mst.ar_id   ), .m_axi_araddr (dma_mst.ar_addr),
	.m_axi_arlen   (dma_mst.ar_len  ), .m_axi_arsize (dma_mst.ar_size),
	.m_axi_arready (dma_mst.ar_ready), .m_axi_arvalid(dma_mst.ar_valid),
	.m_axi_arburst (dma_mst.ar_burst),
	//
	.m_axi_rresp   (dma_mst.r_resp  ), .m_axi_rvalid(dma_mst.r_valid),
	.m_axi_rdata   (dma_mst.r_data  ), .m_axi_rready(dma_mst.r_ready),
    .m_axi_rlast   (dma_mst.r_last  ), .m_axi_rid   (dma_mst.r_id   )
);

wire [7:0] ulpi_output_en;
assign ULPI_data_t = ~ulpi_output_en;

(* keep_hierarchy = "yes" *)
DWC_otg ctrl(
    .hclk(aclk),
    .hreset_n(aresetn),
    .prst_n(1'b1),
    .interrupt(interrupt),
    .scan_mode(1'b0),
    .gp_in(16'b0),
    
    .s_hready_resp  (ahb_hready  ),           // AHB Transfer Done - Out
    .s_hresp        (ahb_hresp   ),           // AHB Transfer Response
    .s_hrdata       (ahb_hrdata  ),           // AHB Read Data
    .s_haddr        (ahb_haddr   ),           // AHB Address Bus
    .s_hsel         (1'b1        ),           // AHB Device Select
    .s_hwrite       (ahb_hwrite  ),           // AHB Transfer Direction
    .s_htrans       (ahb_htrans  ),           // AHB Transfer Type
    .s_hsize        (ahb_hsize   ),           // AHB Transfer Size
    .s_hburst       (ahb_hburst  ),           // AHB Burst Type
    .s_hready       (ahb_hready  ),           // AHB Transfer Done - In
    .s_hwdata       (ahb_hwdata  ),           // AHB Write Data
    .s_hbigendian   (1'b0        ),           // AHB Big Indian Mode
    
    .sys_dma_done   (1'b1        ),
    
    .m_hgrant       (1'b1        ),
    .m_haddr        (dma_haddr   ),
    .m_hprot        (dma_hprot   ),
    .m_htrans       (dma_htrans  ),
    .m_hsize        (dma_hsize   ),
    .m_hburst       (dma_hburst  ),
    .m_hrdata       (dma_hrdata  ),
    .m_hwdata       (dma_hwdata  ),
    .m_hwrite       (dma_hwrite  ),
    .m_hready       (dma_hready_miso),
    .m_hresp        (dma_hresp   ),
    .m_hbigendian   (1'b0        ),
    
    
    .dfifo_h_rdata  (fifo_dout   ),           // DFIFO Read Data
    .dfifo_h_wr_n   (fifo_we     ),           // DFIFO Write - Active low
    .dfifo_h_ce_n   (fifo_ce     ),           // DFIFO Chipselect - Active Low
    .dfifo_h_wdata  (fifo_din    ),           // DFIFO Write Data
    .dfifo_h_addr   (fifo_addr   ),           // DFIFO Write Data
    
    .utmi_clk(ULPI_clk),
    .ulpi_clk(ULPI_clk),
    .ulpi_stp(ULPI_stp),
    .ulpi_dir(ULPI_dir),
    .ulpi_nxt(ULPI_nxt),
    .ulpi_dataout     (ULPI_data_o   ),
    .ulpi_datain      (ULPI_data_i   ),
    .ulpi_data_out_en (ulpi_output_en),
    
    .sof_update_toggle(1'b0),
    .sof_count('0),
    .ss_scaledown_mode(2'b0)
    
    /*
    ,.internal_probes(dbg)
    ,.internal_probes_p(dbg_p)
    */
);

/* // For debugging
(* mark_debug = "true" *)logic [218:0] dbg_p;
(* mark_debug = "true" *)logic [7:0] _ULPI_data_o = ULPI_data_o;
(* mark_debug = "true" *)logic [7:0] _ULPI_data_t = ULPI_data_t;
(* mark_debug = "true" *)logic [7:0] _ULPI_data_i = ULPI_data_i;
(* mark_debug = "true" *)logic _ULPI_nxt = ULPI_nxt;
(* mark_debug = "true" *)logic _ULPI_stp = ULPI_stp;
(* mark_debug = "true" *)logic _ULPI_dir = ULPI_dir;
(* mark_debug = "true" *)logic [218:0] dbg_p_synced;
(* mark_debug = "true" *)logic [61:0] dbg;
stolen_cdc_array_single #(.DEST_SYNC_FF(2), .WIDTH(219)) cdc_d (ULPI_clk, dbg_p, aclk, dbg_p_synced);
*/
  
endmodule

