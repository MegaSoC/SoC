module ethernet_wrapper #(
    parameter C_ASIC_SRAM = 1'b0
) (
    input aclk,
    input aresetn,                     

    output interrupt_0,
 
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
    
    AXI_BUS.Slave   slv
);

wire           mtxclk_0;  
wire  [3:0]    mtxd_0;  
wire           mtxen_0;

wire           mrxclk_0;
wire   [3:0]   mrxd_0;
wire           mrxdv_0;
wire           mrxerr_0;

wire           mcoll_soc, mcoll_ref;
wire           mcrs_soc, mcrs_ref;

stolen_cdc_array_single #(2, 1, 2) crs_cdc(
   .src_clk(rmii_ref_clk),
   .src_in({mcoll_ref, mcrs_ref}),
   .dest_clk(aclk),
   .dest_out({mcoll_soc, mcrs_soc})
);

stolen_cdc_sync_rst cpu_rstgen(
    .dest_clk(rmii_ref_clk),
    .dest_rst(phy_rstn),
    .src_rst(aresetn)
);

axi_ethernetlite #(
  .C_S_AXI_ACLK_PERIOD_PS(7500),
  .C_TX_PING_PONG(1),
  .C_RX_PING_PONG(1),
  .C_SELECT_XPM(!C_ASIC_SRAM)
) eth (
  .s_axi_aclk(aclk),
  .s_axi_aresetn(aresetn),
  .ip2intc_irpt(interrupt_0),
  
  .s_axi_awid(slv.aw_id),
  .s_axi_awaddr(slv.aw_addr[12:0]),
  .s_axi_awlen(slv.aw_len),
  .s_axi_awsize(slv.aw_size),
  .s_axi_awburst(slv.aw_burst),
  .s_axi_awcache(slv.aw_cache),
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
  .s_axi_araddr(slv.ar_addr[12:0]),
  .s_axi_arlen(slv.ar_len),
  .s_axi_arsize(slv.ar_size),
  .s_axi_arburst(slv.ar_burst),
  .s_axi_arcache(slv.ar_cache),
  .s_axi_arvalid(slv.ar_valid),
  .s_axi_arready(slv.ar_ready),
  .s_axi_rid(slv.r_id),
  .s_axi_rdata(slv.r_data),
  .s_axi_rresp(slv.r_resp),
  .s_axi_rlast(slv.r_last),
  .s_axi_rvalid(slv.r_valid),
  .s_axi_rready(slv.r_ready),
    
  .phy_tx_clk(mtxclk_0),
  .phy_rx_clk(mrxclk_0),
  .phy_crs(mcrs_soc),
  .phy_dv(mrxdv_0),
  .phy_rx_data(mrxd_0),
  .phy_col(mcoll_soc),
  .phy_rx_er(mrxerr_0),
  .phy_tx_en(mtxen_0),
  .phy_tx_data(mtxd_0),
  .phy_mdio_i(md_i_0),
  .phy_mdio_o(md_o_0),
  .phy_mdio_t(md_t_0),
  .phy_mdc(mdc_0)
);

mii_to_rmii converter (
    .rst_n(phy_rstn),
    .ref_clk(rmii_ref_clk),
    
    .mac2rmii_tx_en(mtxen_0),
    .mac2rmii_txd(mtxd_0),
    .mac2rmii_tx_er(1'b0),
    .rmii2mac_tx_clk(mtxclk_0),
    .rmii2mac_rx_clk(mrxclk_0),
    .rmii2mac_col(mcoll_ref),
    .rmii2mac_crs(mcrs_ref),
    .rmii2mac_rx_dv(mrxdv_0),
    .rmii2mac_rx_er(mrxerr_0),
    .rmii2mac_rxd(mrxd_0),

    .phy2rmii_crs_dv(rmii_crs_rxdv),
    .phy2rmii_rx_er(rmii_rx_err),
    .phy2rmii_rxd(rmii_rxd),
    .rmii2phy_txd(rmii_txd),
    .rmii2phy_tx_en(rmii_tx_en)
);

endmodule
