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
maxShipCnt    = 15; % Maximum number of ships displayed on the viewer
maxMsgLenBytes = 90; % Maximum message length in bytes

info = struct( ...
    'MessageBytes', char(zeros(maxShipCnt, maxMsgLenBytes)), ...
    'MMSI',         zeros(1, maxShipCnt), ...
    'Longitude',    zeros(1, maxShipCnt), ...
    'Latitude',     zeros(1, maxShipCnt));

coder.varsize('info.MessageBytes', [maxShipCnt, maxMsgLenBytes]);
coder.varsize('rcv', [262144, 1]); % 2^18

% FIX 1: forza vettore colonna.
% L'USRP (e altri SDR) possono restituire un vettore riga (1xN).
% Tutto il codice downstream (helperAISRxPhyPacketSearch, concatenazione
% verticale con ";", coder.varsize [N,1]) assume un vettore colonna.
% Senza questa riga si ottiene "Expected input to be empty, scalar or
% a column vector" o errori di dimensione nel loop.
rcv = receive(:);

% Loop over received samples
while length(rcv) > aisParam.MinPacketLength

    % Detect the strongest burst
    [rcvDet, rcvBoundary] = helperAISRxPhyPacketSearch(rcv, aisParam);

    % Remove the DC offset
    rcvDCFree = rcvDet - mean(rcvDet);

    % Estimate and compensate for the carrier frequency offset
    rcvFreqComp = helperAISRxPhyFreqComp(rcvDCFree, aisParam.SampleRate);

    % Perform Gaussian matched filtering
    rcvFilt = filter(aisParam.h, 1, rcvFreqComp);

    % Synchronization and GMSK demodulation
    [decBits, PrbDetFlag] = helperAISRxPhySyncDemod(rcvFilt, aisParam);

    % Extract message information if preamble is detected
    if PrbDetFlag
        [info, pktCnt, crcCnt] = helperAISRxPhyBitParser(decBits, pktCnt, crcCnt, info);
    end

    % FIX 2: rcvBoundary(1) potrebbe essere 0 se il burst è all'inizio
    % del buffer. rcv(1:0) è un vettore vuoto valido, ma rcv(1:1) sarebbe
    % sbagliato. Aggiunto clamp per sicurezza.
    startIdx = max(1, rcvBoundary(1));
    endIdx   = min(rcvBoundary(2), length(rcv));

    % Discard the samples already processed
    % FIX 3: usa endIdx invece di rcvBoundary(2) direttamente, per evitare
    % indice fuori range se rcvBoundary(2) > length(rcv)
    rcv = [rcv(1:startIdx); rcv(endIdx:end)];
end

pkt.Detected = pktCnt;
pkt.Decoded  = crcCnt;
end