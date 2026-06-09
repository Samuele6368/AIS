function [info,pkt] = helperAISRxPhy(receive,aisParam)
%helperAISRxPhy AIS physical layer decoding
%   [INFO,PKT] = helperAISRxPhy(RECEIVE,AISPARAM) decodes the AIS signals,
%   RECEIVE, by using AIS parameters, AISPARAM. It outputs the decoded
%   information, INFO and packet statistics, PKT.
%
%   INFO is structure of arrays with the following fields:
%
%   MessageBytes: Decoded packet information in bytes.
%   MMSI:         Ship IDs of all the decoded ships.
%   Longitude:    Longitude information of all the decoded ships.
%   Latitude:     Latitude information of all the decoded ships.
%
%   PKT is structure with the following fields:
%   
%   Detected:  Total number of detected AIS packets.
%   Decoded:   Total number of AIS packets for which CRC passes.
%
%   See also AISExample, AISExampleApp.

%   Copyright 2018 The MathWorks, Inc.

%#codegen

% Initialize the decoding parameters for codegen purpose
pktCnt = 0;
crcCnt = 0;
maxShipCnt = 15; % Maximum number of ships that can be displayed on the viewer
maxMsgLenBytes = 90; % Maximum length of message in bytes (initialized for codegen purpose)
info = struct('MessageBytes',char(zeros(maxShipCnt,maxMsgLenBytes)),'MMSI',zeros(1,maxShipCnt),...
     'Longitude',zeros(1,maxShipCnt),'Latitude',zeros(1,maxShipCnt));
coder.varsize('info.MessageBytes',[maxShipCnt,maxMsgLenBytes]);
coder.varsize('rcv',[262144,1]);%2^18
rcv = receive;

% Loop over received samples
while length(rcv) > aisParam.MinPacketLength

    % Detect the strongest burst
    [rcvDet,rcvBoundary] = helperAISRxPhyPacketSearch(rcv,aisParam);

    % Remove the DC offset
    rcvDCFree = rcvDet - mean(rcvDet);

    % Estimate and compensates for the carrier frequency offset
    rcvFreqComp = helperAISRxPhyFreqComp(rcvDCFree,aisParam.SampleRate);

    % Perform Gaussian matched filtering
    rcvFilt = filter(aisParam.h,1,rcvFreqComp);

    % Synchronization and GMSK demodulation
    [decBits,PrbDetFlag] = helperAISRxPhySyncDemod(rcvFilt,aisParam);

    % Extract the message information, if preamble is detected
    if(PrbDetFlag)
         [info,pktCnt,crcCnt] = helperAISRxPhyBitParser(decBits,pktCnt,crcCnt,info);
    end

    % Discard the samples that are already processed
    rcv = [rcv(1:rcvBoundary(1)); rcv(rcvBoundary(2):end)];
end
pkt.Detected = pktCnt;
pkt.Decoded = crcCnt;
end
