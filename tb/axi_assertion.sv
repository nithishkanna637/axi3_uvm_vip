
module mem_assert(clk, res, awvalid, awready, awaddr,
                  wvalid, wready, wdata, wlast,
                  bvalid, bready,
                  arvalid, arready, araddr,
                  rvalid, rready, rdata, rlast);

  input clk, res;

  input        awvalid, awready;
  input [31:0] awaddr;

  input        wvalid, wready, wlast;
  input [31:0] wdata;

  input        bvalid, bready;

  input        arvalid, arready;
  input [31:0] araddr;

  input        rvalid, rready, rlast;
  input [31:0] rdata;

  property reset_check;
    @(posedge clk)
    (res == 0) |-> (awvalid == 0 && wvalid == 0 &&
                    bvalid  == 0 && arvalid == 0 &&
                    rvalid  == 0);
  endproperty
  RESET_CHECK: assert property(reset_check)
    else $error("RESET FAIL — valid signal high during reset");

  property post_reset_known;
    @(posedge clk)
    (res == 1) |-> (!$isunknown(awvalid) && !$isunknown(arvalid) &&
                    !$isunknown(wvalid)  && !$isunknown(rvalid)  &&
                    !$isunknown(bvalid));
  endproperty
  POST_RESET_KNOWN: assert property(post_reset_known)
    else $error("POST RESET FAIL — X/Z detected on valid signals");

  property awvalid_stable;
    @(posedge clk) disable iff (res == 0)
    (awvalid == 1 && awready == 0) |=> (awvalid == 1);
  endproperty
  AWVALID_STABLE: assert property(awvalid_stable)
    else $error("AWVALID STABLE FAIL — awvalid dropped before awready");

  property awaddr_stable;
    @(posedge clk) disable iff (res == 0)
    (awvalid == 1 && awready == 0) |=> ($stable(awaddr));
  endproperty
  AWADDR_STABLE: assert property(awaddr_stable)
    else $error("AWADDR STABLE FAIL — awaddr changed before handshake");

  property wvalid_stable;
    @(posedge clk) disable iff (res == 0)
    (wvalid == 1 && wready == 0) |=> (wvalid == 1);
  endproperty
  WVALID_STABLE: assert property(wvalid_stable)
    else $error("WVALID STABLE FAIL — wvalid dropped before wready");

  property wdata_stable;
    @(posedge clk) disable iff (res == 0)
    (wvalid == 1 && wready == 0) |=> ($stable(wdata));
  endproperty
  WDATA_STABLE: assert property(wdata_stable)
    else $error("WDATA STABLE FAIL — wdata changed before handshake");

  property arvalid_stable;
    @(posedge clk) disable iff (res == 0)
    (arvalid == 1 && arready == 0) |=> (arvalid == 1);
  endproperty
  ARVALID_STABLE: assert property(arvalid_stable)
    else $error("ARVALID STABLE FAIL — arvalid dropped before arready");

  property araddr_stable;
    @(posedge clk) disable iff (res == 0)
    (arvalid == 1 && arready == 0) |=> ($stable(araddr));
  endproperty
  ARADDR_STABLE: assert property(araddr_stable)
    else $error("ARADDR STABLE FAIL — araddr changed before handshake");

  property awvalid_timeout;
    @(posedge clk) disable iff (res == 0)
    (awvalid == 1) |-> ##[1:16] (awready == 1);
  endproperty
  AWVALID_TIMEOUT: assert property(awvalid_timeout)
    else $error("AWVALID TIMEOUT — awready not seen within 16 cycles");

  property arvalid_timeout;
    @(posedge clk) disable iff (res == 0)
    (arvalid == 1) |-> ##[1:16] (arready == 1);
  endproperty
  ARVALID_TIMEOUT: assert property(arvalid_timeout)
    else $error("ARVALID TIMEOUT — arready not seen within 16 cycles");

  property bvalid_stable;
    @(posedge clk) disable iff (res == 0)
    (bvalid == 1 && bready == 0) |=> (bvalid == 1);
  endproperty
  BVALID_STABLE: assert property(bvalid_stable)
    else $error("BVALID STABLE FAIL — bvalid dropped before bready");

  property rvalid_stable;
    @(posedge clk) disable iff (res == 0)
    (rvalid == 1 && rready == 0) |=> (rvalid == 1);
  endproperty
  RVALID_STABLE: assert property(rvalid_stable)
    else $error("RVALID STABLE FAIL — rvalid dropped before rready");

  property rdata_known;
    @(posedge clk) disable iff (res == 0)
    (rvalid == 1) |-> (!$isunknown(rdata));
  endproperty
  RDATA_KNOWN: assert property(rdata_known)
    else $error("RDATA KNOWN FAIL — X/Z on rdata when rvalid high");

  property wdata_known;
    @(posedge clk) disable iff (res == 0)
    (wvalid == 1) |-> (!$isunknown(wdata));
  endproperty
  WDATA_KNOWN: assert property(wdata_known)
    else $error("WDATA KNOWN FAIL — X/Z on wdata when wvalid high");

  property awaddr_known;
    @(posedge clk) disable iff (res == 0)
    (awvalid == 1) |-> (!$isunknown(awaddr));
  endproperty
  AWADDR_KNOWN: assert property(awaddr_known)
    else $error("AWADDR KNOWN FAIL — X/Z on awaddr when awvalid high");

  property araddr_known;
    @(posedge clk) disable iff (res == 0)
    (arvalid == 1) |-> (!$isunknown(araddr));
  endproperty
  ARADDR_KNOWN: assert property(araddr_known)
    else $error("ARADDR KNOWN FAIL — X/Z on araddr when arvalid high");

  property rlast_before_rvalid_drop;
    @(posedge clk) disable iff (res == 0)
    (rvalid == 1 && rready == 1 && rlast == 0) |=> (rvalid == 1);
  endproperty
  RLAST_CHECK: assert property(rlast_before_rvalid_drop)
    else $error("RLAST FAIL — rvalid dropped without rlast being asserted");

  property wlast_before_wvalid_drop;
    @(posedge clk) disable iff (res == 0)
    (wvalid == 1 && wready == 1 && wlast == 0) |=> (wvalid == 1);
  endproperty
  WLAST_CHECK: assert property(wlast_before_wvalid_drop)
    else $error("WLAST FAIL — wvalid dropped without wlast being asserted");

endmodule
