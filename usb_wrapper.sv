module usb_wrapper #(
    parameter C_ASIC_SRAM = 0
)  (
    input aclk,
    input aresetn,
    AXI_BUS.Slave slv,
    output interrupt,
    
    input  wire       ULPI_clk,
    input  wire [7:0] ULPI_data_i,
    output wire [7:0] ULPI_data_o,
    output wire [7:0] ULPI_data_t,
    output wire       ULPI_resetn,
    output wire       ULPI_stp,
    input  wire       ULPI_dir,
    input  wire       ULPI_nxt
);
assign ULPI_resetn = aresetn;

(* mark_debug = "true" *)logic [31:0]     ahb_haddr;       // ahb bus address
logic [2:0]      ahb_hburst;      // burst
(* mark_debug = "true" *)logic [2:0]      ahb_hsize;       // size of bus transaction (possible values 0,1,2,3)
(* mark_debug = "true" *)logic [1:0]      ahb_htrans;      // Transaction type (possible values 0,2 only right now)
(* mark_debug = "true" *)logic            ahb_hwrite;      // ahb bus write
(* mark_debug = "true" *)logic [31:0]     ahb_hwdata;      // ahb bus write data
(* mark_debug = "true" *)logic [31:0]     ahb_hrdata;      // ahb bus read data
(* mark_debug = "true" *)logic            ahb_hready;      // slave ready to accept transaction
(* mark_debug = "true" *)logic [1:0]      ahb_hresp;       // slave response (high indicates erro)

(* mark_debug = "true" *) logic [218:0] dbg_p;
logic [218:0] dbg_p_synced;
(* mark_debug = "true" *) logic [61:0] dbg;
(* mark_debug = "true" *) wire usb_intr = interrupt;

wire [7:0] ulpi_output_en;
assign ULPI_data_t = ~ulpi_output_en;

stolen_cdc_array_single #(.DEST_SYNC_FF(2), .WIDTH(219)) cdc_d (UTMI_clk, dbg_p, aclk, dbg_p_synced);

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
wire [10:0] fifo_addr;
wire fifo_ce, fifo_we;

generate if (C_ASIC_SRAM) begin
    S018SP_RAM_SP_W2048_B35_M4 usb_fifo_s (
        .Q(fifo_dout),
        .CLK(aclk),
        .CEN(fifo_ce),
        .WEN(fifo_we),
        .A(fifo_addr),
        .D(fifo_din)
    );
end else begin
    xpm_memory_spram #(
          .ADDR_WIDTH_A(11),              // DECIMAL
          .AUTO_SLEEP_TIME(0),           // DECIMAL
          .BYTE_WRITE_WIDTH_A(35),       // DECIMAL
          .CASCADE_HEIGHT(0),            // DECIMAL
          .ECC_MODE("no_ecc"),           // String
          .MEMORY_INIT_FILE("none"),     // String
          .MEMORY_INIT_PARAM("0"),       // String
          .MEMORY_OPTIMIZATION("true"),  // String
          .MEMORY_PRIMITIVE("auto"),     // String
          .MEMORY_SIZE(71680),            // DECIMAL
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

DWC_otg ctrl(
    .hclk(aclk),
    .hreset_n(aresetn),
    .prst_n(ULPI_resetn),
    .interrupt(interrupt),
    .scan_mode(1'b0),
    .gp_in(16'b0),
    
    .s_hready_resp  (ahb_hready  ),           // AHB Transfer Done - Out
    .s_hresp        (ahb_hresp   ),           // AHB Transfer Response
    .s_hrdata       (ahb_hrdata  ),           // AHB Read Data
    .s_haddr        (ahb_haddr   ),           // AHB Address Bus
    .s_hsel         ('1          ),           // AHB Device Select
    .s_hwrite       (ahb_hwrite  ),           // AHB Transfer Direction
    .s_htrans       (ahb_htrans  ),           // AHB Transfer Type
    .s_hsize        (ahb_hsize   ),           // AHB Transfer Size
    .s_hburst       (ahb_hburst  ),           // AHB Burst Type
    .s_hready       ('1          ),           // AHB Transfer Done - In
    .s_hwdata       (ahb_hwdata  ),           // AHB Write Data
    .s_hbigendian   ('0          ),           // AHB Big Indian Mode
    
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
    .ss_scaledown_mode(2'b0),
    
    .internal_probes(dbg),
    .internal_probes_p(dbg_p)
);
    
endmodule

