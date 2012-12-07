// MergeFork.bsv
// Copyright (c) 2012 Atomic Rules LLC - ALL RIGHTS RESERVED
// Christina Smith
// FIXME! Remove L2 header adding logic from merge fork, it is not merging or forking and should be decoupled from the concern of merge-fork
import GetPut     ::*;
import FIFO       ::*;
import FIFOF      ::*;
import Vector     ::*;
import BRAM       ::*;

import Accum      ::*;
import DPPDefs    ::*;
import MLDefs     ::*;

interface MergeForkFDUIfc;
  interface Client#(HexBDG, HexBDG) egress;
  interface Put#(HexBDG) ingress;
  interface Get#(HexBDG) ack;
endinterface

(* synthesize *)
module mkMergeForkFDU(MergeForkFDUIfc);

FIFOF#(HexBDG)               datagramIngressF   <- mkFIFOF;
FIFO#(HexBDG)                datagramEgressF    <- mkFIFO;
FIFO#(HexBDG)                ackIngressF        <- mkFIFO;
FIFO#(HexBDG)                ackEgressF         <- mkFIFO;
Reg#(Vector#(6, Bit#(8)))    macDst             <- mkReg(unpack('h000102030405));
Reg#(Vector#(6, Bit#(8)))    macSrc             <- mkReg(unpack('h151413121110));
Reg#(Vector#(2, Bit#(8)))    ethType            <- mkReg(unpack('h3333));
Reg#(Bool)                   isDGheader         <- mkReg(True);
Reg#(Bool)                   isAckHeader        <- mkReg(True);
 
rule pumpHeader(isDGheader && datagramIngressF.notEmpty);
  Vector#(12, Bit#(8)) macAddrs = append(macDst, macSrc);
  HexBDG x = HexBDG{data: padHexByte(append(macAddrs, ethType)), nbVal: 16, isEOP: False}; // FIXME! This is totally wrong, there are only 14 valid bytes in an L2 header.
  datagramEgressF.enq(x);
  isDGheader <= False;
endrule

rule pumpFrame(!isDGheader);                       // Will need to multiplex multiple FDUs
  let y = datagramIngressF.first;
  if(y.isEOP) isDGheader <= True;
  datagramEgressF.enq(y);
  datagramIngressF.deq;
endrule

rule rmAckHeader(isAckHeader);
  HexBDG l2header = ackIngressF.first;
  ackIngressF.deq;
  isAckHeader <= False;
endrule

rule pumpAck(!isAckHeader);                        // Ack will always go to AckTracker
//rule pumpAck;                        // Ack will always go to AckTracker
  let y = ackIngressF.first;
  if(y.isEOP)isAckHeader <= True;
  ackEgressF.enq(y);
  ackIngressF.deq;
endrule

interface ingress = toPut(datagramIngressF);//TODO:input FIFO
interface ack = toGet(ackEgressF); // TODO: to be used for ACKS
  
interface Client egress;
  interface request = toGet(datagramEgressF); //TODO: output FIFO
  interface response = toPut(ackIngressF); //TODO: to be used for ACKS
endinterface
endmodule
