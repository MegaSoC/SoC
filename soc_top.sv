(* keep_hierarchy = "yes" *)
module soc_top #(
    parameter C_ASIC_SRAM = 1
) (
    input soc_clk,
    input cpu_clk,
    input aresetn,
    
    output [5:0]  mem_axi_awid,
    output [31:0] mem_axi_awaddr,
    output [7:0]  mem_axi_awlen,
    output [2:0]  mem_axi_awsize,
    output [1:0]  mem_axi_awburst,
    output        mem_axi_awvalid,
    input         mem_axi_awready,
    output [31:0] mem_axi_wdata,
    output [3:0]  mem_axi_wstrb,
    output        mem_axi_wlast,
    output        mem_axi_wvalid,
    input         mem_axi_wready,
    output        mem_axi_bready,
    input  [5:0]  mem_axi_bid,
    input  [1:0]  mem_axi_bresp,
    input         mem_axi_bvalid,
    output [5:0]  mem_axi_arid,
    output [31:0] mem_axi_araddr,
    output [7:0]  mem_axi_arlen,
    output [2:0]  mem_axi_arsize,
    output [1:0]  mem_axi_arburst,
    output        mem_axi_arvalid,
    input         mem_axi_arready,
    output        mem_axi_rready,
    input [5:0]   mem_axi_rid,
    input [31:0]  mem_axi_rdata,
    input [1:0]   mem_axi_rresp,
    input         mem_axi_rlast,
    input         mem_axi_rvalid,
    
    output [3:0]  csn_o,
    output        sck_o,
    input         sdo_i,
    output        sdo_o,
    output        sdo_en, 
    input         sdi_i,
    output        sdi_o,
    output        sdi_en,
    
    input         uart_txd_i,
    output        uart_txd_o,
    output        uart_txd_en,
    input         uart_rxd_i,
    output        uart_rxd_o,
    output        uart_rxd_en,
    
    input           rmii_ref_clk,  
    output  [1:0]   rmii_txd,    
    output          rmii_tx_en,   

    input   [1:0]   rmii_rxd,    
    input           rmii_crs_rxdv,   
    input           rmii_rx_err,
    
    input           md_i_0,      
    output          mdc_0,
    output          md_o_0,
    output          md_t_0,
    output          phy_rstn,
    
    output [15:0]   led,
    
    input  [3:0]    sd_dat_i,
    output [3:0]    sd_dat_o,
    output          sd_dat_t,
    input           sd_cmd_i,
    output          sd_cmd_o,
    output          sd_cmd_t,
    output          sd_clk,
    
    input           ULPI_clk,
    input     [7:0] ULPI_data_i,
    output    [7:0] ULPI_data_o,
    output    [7:0] ULPI_data_t,
    output          ULPI_stp,
    input           ULPI_dir,
    input           ULPI_nxt,
    
    output          CDBUS_tx,
    output          CDBUS_tx_en,
    input           CDBUS_rx
);

`define AXI_LINE(name) AXI_BUS #(.AXI_ADDR_WIDTH(32), .AXI_DATA_WIDTH(32), .AXI_ID_WIDTH(4)) name()
`define AXI_LITE_LINE(name) AXI_LITE #(.AXI_ADDR_WIDTH(32), .AXI_DATA_WIDTH(32)) name()
`define AXI_LINE_W(name, idw) AXI_BUS #(.AXI_ADDR_WIDTH(32), .AXI_DATA_WIDTH(32), .AXI_ID_WIDTH(idw)) name()

`AXI_LINE(cpu_m);
`AXI_LINE(sdc_dma_m);
`AXI_LINE(usb_dma_m);
`AXI_LINE(mem_m);

`AXI_LINE(spi_s);
`AXI_LINE(eth_s);
`AXI_LINE(intc_s);
`AXI_LINE(sdc_s);

`AXI_LINE_W(mig_s, 6);
`AXI_LINE(apb_s);
`AXI_LINE(cfg_s);
`AXI_LINE(usb_s);
`AXI_LINE(err_s);
error_slave_wrapper err_slave_err(soc_clk, aresetn, err_s);

wire spi_interrupt;
wire eth_interrupt;
wire uart_interrupt;
wire cpu_interrupt;
wire sd_dat_interrupt, sd_cmd_interrupt;
wire usb_interrupt;
wire cdbus_interrupt;
// Ethernet should be at lowest bit because the configuration in intc
// (interrupt of emaclite is a pulse interrupt, not level) 
wire [6:0] interrupts = {cdbus_interrupt, usb_interrupt, sd_dat_interrupt, sd_cmd_interrupt, uart_interrupt, spi_interrupt, eth_interrupt};
cpu_wrapper #(
    .C_ASIC_SRAM(C_ASIC_SRAM)
) cpu (.cpu_clk(cpu_clk), .m0_clk(soc_clk), .m0_aresetn(aresetn), .interrupt(cpu_interrupt), .m0(cpu_m));

function automatic logic [3:0] periph_addr_sel(input logic [ 31 : 0 ] addr);
    automatic logic [3:0] select;
    if (addr[31:27] == 5'b0) // MIG
        select = 1;
    else if (addr[31:20]==12'h1fc || addr[31:16]==16'h1fe8) // SPI
        select = 5;
    else if (addr[31:16]==16'h1fe4 || addr[31:16]==16'h1fe7) // APB
        select = 3; 
    else if (addr[31:16]==16'h1fd0) // conf
        select = 2;
    else if (addr[31:16]==16'h1ff0) // Ethernet
        select = 4;
    else if (addr[31:16]==16'h1fb0) // Interrupt Controller
        select = 6;
    else if (addr[31:20]==12'h1fa) // USB Controller
        select = 7;
    else if (addr[31:16]==16'h1fe1) // SD Controller
        select = 8;
    else // ERROR
        select = 0;
    return select;
endfunction

my_axi_demux_intf #(
    .AXI_ID_WIDTH(4),
    .AXI_ADDR_WIDTH(32),
    .AXI_DATA_WIDTH(32),
    .NO_MST_PORTS(9),
    .MAX_TRANS(2),
    .AXI_LOOK_BITS(2),
    .FALL_THROUGH(1)
) cpu_demux (
    .clk_i(soc_clk),
    .rst_ni(aresetn),
    .test_i(1'b0),
    .slv_aw_select_i(periph_addr_sel(cpu_m.aw_addr)),
    .slv_ar_select_i(periph_addr_sel(cpu_m.ar_addr)),
    .slv(cpu_m),
    .mst0(err_s),
    .mst1(mem_m),
    .mst2(cfg_s),
    .mst3(apb_s),
    .mst4(eth_s),
    .mst5(spi_s),
    .mst6(intc_s),
    .mst7(usb_s),
    .mst8(sdc_s)
);

axi_mux_intf #(
    .SLV_AXI_ID_WIDTH(4),
    .MST_AXI_ID_WIDTH(6),
    .AXI_ADDR_WIDTH(32),
    .AXI_DATA_WIDTH(32),
    .NO_SLV_PORTS(3),
    .MAX_W_TRANS(2),
    .FALL_THROUGH(1)
) mem_mux (
    .clk_i(soc_clk),
    .rst_ni(aresetn),
    .test_i(1'b0),
    .slv0(sdc_dma_m),
    .slv1(mem_m),
    .slv2(usb_dma_m),
    .mst(mig_s)
);

axi_intc_wrapper #(
    .C_NUM_INTR_INPUTS($bits(interrupts))
) intc (
    .aslv(intc_s),
    .aclk(soc_clk),
    .aresetn(aresetn),
    .irq_i(interrupts),
    .irq_o(cpu_interrupt)
);

//eth top
ethernet_wrapper #(
    .C_ASIC_SRAM(C_ASIC_SRAM)
) ethernet (
    .aclk        (soc_clk  ),
    .aresetn     (aresetn  ),      
    .slv         (eth_s    ),

    .interrupt_0 (eth_interrupt),
 
    .rmii_ref_clk (rmii_ref_clk   ),
    .rmii_txd     (rmii_txd       ),    
    .rmii_tx_en   (rmii_tx_en     ),   

    .rmii_rxd     (rmii_rxd       ),    
    .rmii_crs_rxdv(rmii_crs_rxdv  ),   
    .rmii_rx_err  (rmii_rx_err    ),  

    // MDIO
    .mdc_0        (mdc_0    ),
    .md_i_0       (md_i_0   ),
    .md_o_0       (md_o_0   ),       
    .md_t_0       (md_t_0   ),
    .phy_rstn     (phy_rstn )
);

sdc_wrapper sdc(
    .aclk(soc_clk),
    .aresetn(aresetn),
    
    .slv(sdc_s),
    .dma_mst(sdc_dma_m),
    .int_cmd(sd_cmd_interrupt),
    .int_data(sd_dat_interrupt),
    
    .sd_dat_i(sd_dat_i),
    .sd_dat_o(sd_dat_o),
    .sd_dat_t(sd_dat_t),
    .sd_cmd_i(sd_cmd_i),
    .sd_cmd_o(sd_cmd_o),
    .sd_cmd_t(sd_cmd_t),
    .sd_clk(sd_clk)
);

usb_wrapper #(
    .C_ASIC_SRAM(C_ASIC_SRAM)
) usb_ctrl (
   .aclk(soc_clk),
   .aresetn(aresetn),
   .slv(usb_s),
   .interrupt(usb_interrupt),
   .dma_mst(usb_dma_m),

   .ULPI_clk,
   .ULPI_data_i,
   .ULPI_data_o,
   .ULPI_data_t,
   .ULPI_stp,
   .ULPI_dir,
   .ULPI_nxt
);

//confreg
confreg CONFREG(
    .aclk           (soc_clk            ),       
    .aresetn        (aresetn            ),       
    .s_awid         (cfg_s.aw_id        ),
    .s_awaddr       (cfg_s.aw_addr      ),
    .s_awlen        (cfg_s.aw_len       ),
    .s_awsize       (cfg_s.aw_size      ),
    .s_awburst      (cfg_s.aw_burst     ),
    .s_awlock       ('0                 ),
    .s_awcache      ('0                 ),
    .s_awprot       ('0                 ),
    .s_awvalid      (cfg_s.aw_valid     ),
    .s_awready      (cfg_s.aw_ready     ),
    .s_wready       (cfg_s.w_ready      ),
    .s_wdata        (cfg_s.w_data       ),
    .s_wstrb        (cfg_s.w_strb       ),
    .s_wlast        (cfg_s.w_last       ),
    .s_wvalid       (cfg_s.w_valid      ),
    .s_bid          (cfg_s.b_id         ),
    .s_bresp        (cfg_s.b_resp       ),
    .s_bvalid       (cfg_s.b_valid      ),
    .s_bready       (cfg_s.b_ready      ),
    .s_arid         (cfg_s.ar_id        ),
    .s_araddr       (cfg_s.ar_addr      ),
    .s_arlen        (cfg_s.ar_len       ),
    .s_arsize       (cfg_s.ar_size      ),
    .s_arburst      (cfg_s.ar_burst     ),
    .s_arlock       ('0                 ),
    .s_arcache      ('0                 ),
    .s_arprot       ('0                 ),
    .s_arvalid      (cfg_s.ar_valid     ),
    .s_arready      (cfg_s.ar_ready     ),
    .s_rready       (cfg_s.r_ready      ),
    .s_rid          (cfg_s.r_id         ),
    .s_rdata        (cfg_s.r_data       ),
    .s_rresp        (cfg_s.r_resp       ),
    .s_rlast        (cfg_s.r_last       ),
    .s_rvalid       (cfg_s.r_valid      ),
    
    .order_addr_reg    (                ),
    .write_dma_end     (1'b0            ),
    .finish_read_order (1'b0            ),

    .led            (led)
);

spi_flash_ctrl SPI (                                         
    .aclk           (soc_clk            ),       
    .aresetn        (aresetn            ),       
    .spi_addr       (16'h1fe8           ),
    .fast_startup   (1'b0               ),
    .s_awid         (spi_s.aw_id        ),
    .s_awaddr       (spi_s.aw_addr      ),
    .s_awlen        (spi_s.aw_len[3:0]       ),
    .s_awsize       (spi_s.aw_size      ),
    .s_awburst      (spi_s.aw_burst     ),
    .s_awlock       ('0                 ),
    .s_awcache      ('0                 ),
    .s_awprot       ('0                 ),
    .s_awvalid      (spi_s.aw_valid     ),
    .s_awready      (spi_s.aw_ready     ),
    .s_wready       (spi_s.w_ready      ),
    .s_wdata        (spi_s.w_data       ),
    .s_wstrb        (spi_s.w_strb       ),
    .s_wlast        (spi_s.w_last       ),
    .s_wvalid       (spi_s.w_valid      ),
    .s_bid          (spi_s.b_id         ),
    .s_bresp        (spi_s.b_resp       ),
    .s_bvalid       (spi_s.b_valid      ),
    .s_bready       (spi_s.b_ready      ),
    .s_arid         (spi_s.ar_id        ),
    .s_araddr       (spi_s.ar_addr      ),
    .s_arlen        (spi_s.ar_len[3:0]       ),
    .s_arsize       (spi_s.ar_size      ),
    .s_arburst      (spi_s.ar_burst     ),
    .s_arlock       ('0                 ),
    .s_arcache      ('0                 ),
    .s_arprot       ('0                 ),
    .s_arvalid      (spi_s.ar_valid     ),
    .s_arready      (spi_s.ar_ready     ),
    .s_rready       (spi_s.r_ready      ),
    .s_rid          (spi_s.r_id         ),
    .s_rdata        (spi_s.r_data       ),
    .s_rresp        (spi_s.r_resp       ),
    .s_rlast        (spi_s.r_last       ),
    .s_rvalid       (spi_s.r_valid      ),
    
    .power_down_req (1'b0              ),
    .power_down_ack (                  ),
    .csn_o          (csn_o         ),
    .sck_o          (sck_o         ),
    .sdo_i          (sdo_i         ),
    .sdo_o          (sdo_o         ),
    .sdo_en         (sdo_en        ), // active low
    .sdi_i          (sdi_i         ),
    .sdi_o          (sdi_o         ),
    .sdi_en         (sdi_en        ),
    .inta_o         (spi_interrupt )
);

axi2apb_misc APB_DEV 
(
.clk                (soc_clk               ),
.rst_n              (aresetn            ),

.axi_s_awid         (apb_s.aw_id        ),
.axi_s_awaddr       (apb_s.aw_addr      ),
.axi_s_awlen        (apb_s.aw_len[3:0]  ),
.axi_s_awsize       (apb_s.aw_size      ),
.axi_s_awburst      (apb_s.aw_burst     ),
.axi_s_awlock       ('0                 ),
.axi_s_awcache      ('0                 ),
.axi_s_awprot       ('0                 ),
.axi_s_awvalid      (apb_s.aw_valid     ),
.axi_s_awready      (apb_s.aw_ready     ),
.axi_s_wready       (apb_s.w_ready      ),
.axi_s_wdata        (apb_s.w_data       ),
.axi_s_wstrb        (apb_s.w_strb       ),
.axi_s_wlast        (apb_s.w_last       ),
.axi_s_wvalid       (apb_s.w_valid      ),
.axi_s_bid          (apb_s.b_id         ),
.axi_s_bresp        (apb_s.b_resp       ),
.axi_s_bvalid       (apb_s.b_valid      ),
.axi_s_bready       (apb_s.b_ready      ),
.axi_s_arid         (apb_s.ar_id        ),
.axi_s_araddr       (apb_s.ar_addr      ),
.axi_s_arlen        (apb_s.ar_len[3:0]  ),
.axi_s_arsize       (apb_s.ar_size      ),
.axi_s_arburst      (apb_s.ar_burst     ),
.axi_s_arlock       ('0                 ),
.axi_s_arcache      ('0                 ),
.axi_s_arprot       ('0                 ),
.axi_s_arvalid      (apb_s.ar_valid     ),
.axi_s_arready      (apb_s.ar_ready     ),
.axi_s_rready       (apb_s.r_ready      ),
.axi_s_rid          (apb_s.r_id         ),
.axi_s_rdata        (apb_s.r_data       ),
.axi_s_rresp        (apb_s.r_resp       ),
.axi_s_rlast        (apb_s.r_last       ),
.axi_s_rvalid       (apb_s.r_valid      ),


.uart0_txd_i        (uart_txd_i      ),
.uart0_txd_o        (uart_txd_o      ),
.uart0_txd_oe       (uart_txd_en     ),
.uart0_rxd_i        (uart_rxd_i      ),
.uart0_rxd_o        (uart_rxd_o      ),
.uart0_rxd_oe       (uart_rxd_en     ),
.uart0_rts_o        (       ),
.uart0_dtr_o        (       ),
.uart0_cts_i        (1'b0   ),
.uart0_dsr_i        (1'b0   ),
.uart0_dcd_i        (1'b0   ),
.uart0_ri_i         (1'b0   ),
.uart0_int          (uart_interrupt),

.cdbus_int          (cdbus_interrupt),
.cdbus_tx           (CDBUS_tx),
.cdbus_rx           (CDBUS_rx),
.cdbus_tx_en        (CDBUS_tx_en)
);

    assign mem_axi_awid = mig_s.aw_id;
    assign mem_axi_awaddr = mig_s.aw_addr;
    assign mem_axi_awlen = mig_s.aw_len;
    assign mem_axi_awsize = mig_s.aw_size;
    assign mem_axi_awburst = mig_s.aw_burst;
    assign mem_axi_awvalid = mig_s.aw_valid;
    assign mig_s.aw_ready = mem_axi_awready;
    assign mem_axi_wdata = mig_s.w_data;
    assign mem_axi_wstrb = mig_s.w_strb;
    assign mem_axi_wlast = mig_s.w_last;
    assign mem_axi_wvalid = mig_s.w_valid;
    assign mig_s.w_ready = mem_axi_wready;
    assign mem_axi_bready = mig_s.b_ready;
    assign mig_s.b_id = mem_axi_bid;
    assign mig_s.b_resp = mem_axi_bresp;
    assign mig_s.b_valid = mem_axi_bvalid;
    assign mem_axi_arid = mig_s.ar_id;
    assign mem_axi_araddr = mig_s.ar_addr;
    assign mem_axi_arlen = mig_s.ar_len;
    assign mem_axi_arsize = mig_s.ar_size;
    assign mem_axi_arburst = mig_s.ar_burst;
    assign mem_axi_arvalid = mig_s.ar_valid;
    assign mig_s.ar_ready = mem_axi_arready;
    assign mem_axi_rready = mig_s.r_ready;
    assign mig_s.r_id = mem_axi_rid;
    assign mig_s.r_data = mem_axi_rdata;
    assign mig_s.r_resp = mem_axi_rresp;
    assign mig_s.r_last = mem_axi_rlast;
    assign mig_s.r_valid = mem_axi_rvalid;

endmodule
