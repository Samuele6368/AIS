function [info,pktCnt,crcCnt] = helperAISRxPhyBitParser(decBits,pktCnt,crcCnt,info)
%helperAISRxPhyBitParser Bit parser for AIS frame
%
%   [INFO,PKTCNT,CRCCNT] = helperAISRxPhyBitParser(DECBITS,PKTCNT,CRCCNT,INFO) 
%   checks for the start flag in the decoded bits, DECBITS, and decodes the
%   AIS frame based on message type. Decoded packet statistics such as
%   packet counter, PKTCNT, and valid CRC counter, CRCCNT, are computed.
%
%   INFO is structure of arrays with the following fields:
%
%   MessageBytes: Decoded packet information in bytes.
%   MMSI:         Ship IDs of all the decoded ships.
%   Longitude:    Longitude information of all the decoded ships.
%   Latitude:     Latitude information of all the decoded ships.
%   
%   PKTCNT is total number of detected AIS packets.
%   
%   CRCCNT is total number of AIS packets for which CRC passes.
%
%   See also AISExample, AISExampleApp.

%   Copyright 2018-2021 The MathWorks, Inc.

%#codegen

% Initialization for codegen purpose
maxMsgLenBytes = 90; % Maximum length of message in bytes (initialized for codegen purpose)
tmp.MessageBytes = char(zeros(1,maxMsgLenBytes));
tmp.MMSI = 0;
tmp.Longitude = 0;
tmp.Latitude = 0;

% Search for the start byte flag (0x7E)
StartFlag = [0 1 1 1 1 1 1 0].';
startBit = 1;
for ii=1:length(decBits)-7
    RxSF = decBits(ii:ii+7);
    if isequal(RxSF, StartFlag)
        startBit = ii+8;
        break;
    else
        startBit = 1;
    end
end

% Discard bits corresponding to start byte
payloadBits = decBits(startBit:end);
if(length(payloadBits)< 24)     % 16-bit CRC and 8-bit end flag
    validCRC = false;
    ubitsTrim = zeros(480,1);
    msgID = 0;
else
    % Decode message type
    msgID = bit2int(payloadBits(3:8),6,false);
    
    % Unstuff payload bits
    unStuffBits = unStuff(payloadBits);
    tempIDSet = [1,2,3,4,9,11,18];
    
    % Define end index based on message type
    switch msgID
        case tempIDSet(tempIDSet==msgID)
            endIndex = 184;
        case 19
            endIndex = 328;
        case 21
            endIndex = 288;
        case 27
            endIndex = 112;
        otherwise
            endIndex = length(unStuffBits);
    end
    
    % Trim the packet up to end index
    if(endIndex > length(unStuffBits))
        endIndex = length(unStuffBits);
    end
    ubitsTrim = unStuffBits(1:endIndex);
    
    % CRC detection
    crcDet = comm.CRCDetector('Polynomial', [1 0 0 0 1 0 0 0 0 0 0 1 0 0 0 0 1],...
        'InitialConditions',1,'DirectMethod',true,'FinalXOR',1);
    [~, err] = crcDet(ubitsTrim(1:endIndex));
    validCRC = ~err;
    
end

% Data bits decoding
if (validCRC)
    % Un Flip the data bits
    if(rem(length(ubitsTrim),8)~= 0)
        dummy = zeros(1,8-rem(length(ubitsTrim),8)).';
        ubitsTrim = [ubitsTrim; dummy];
    end
    flippedBits = flipBytes(ubitsTrim);
    tmp.MessageBytes = bitsToHex(flippedBits);
    tmp.MMSI = bit2int(flippedBits(9:38),30);
    posResFactor1 = 10000;   % Precision with a resolution of 1/10000 min of the value
    posResFactor2 = 10;  % Precision with a resolution of 1/10 min of the value
    secPerMin = 60;
    scaleFact1 = posResFactor1*secPerMin;
    scaleFact2 = posResFactor2*secPerMin;
    switch msgID
        case 1
            tmp.Longitude = (-2^27*flippedBits(62)+2.^(26:-1:0)*flippedBits(63:89))/scaleFact1;
            tmp.Latitude = (-2^26*flippedBits(90)+2.^(25:-1:0)*flippedBits(91:116))/scaleFact1;
        case 2
            tmp.Longitude = (-2^27*flippedBits(62)+2.^(26:-1:0)*flippedBits(63:89))/scaleFact1;
            tmp.Latitude = (-2^26*flippedBits(90)+2.^(25:-1:0)*flippedBits(91:116))/scaleFact1;
        case 3
            tmp.Longitude = (-2^27*flippedBits(62)+2.^(26:-1:0)*flippedBits(63:89))/scaleFact1;
            tmp.Latitude = (-2^26*flippedBits(90)+2.^(25:-1:0)*flippedBits(91:116))/scaleFact1;
        case 4
            tmp.Longitude = 2.^(27:-1:0)*flippedBits(80:107)/scaleFact1;
            tmp.Latitude = 2.^(26:-1:0)*flippedBits(108:134)/scaleFact1;
        case 11
            tmp.Longitude = 2.^(27:-1:0)*flippedBits(80:107)/scaleFact1;
            tmp.Latitude = 2.^(26:-1:0)*flippedBits(108:134)/scaleFact1;
        case 17
            tmp.Longitude = 2.^(27:-1:0)*flippedBits(41:68)/scaleFact2;
            tmp.Latitude = 2.^(26:-1:0)*flippedBits(69:95)/scaleFact2;
        case 18
            tmp.Longitude = (-2^27*flippedBits(58)+2.^(26:-1:0)*flippedBits(59:85))/scaleFact1;
            tmp.Latitude = (-2^26*flippedBits(86)+2.^(25:-1:0)*flippedBits(87:112))/scaleFact1;
        case 19
            tmp.Longitude = 2.^(27:-1:0)*flippedBits(58:85)/scaleFact1;
            tmp.Latitude = 2.^(26:-1:0)*flippedBits(86:112)/scaleFact1;
        case 21
            tmp.Longitude = 2.^(27:-1:0)*flippedBits(165:192)/scaleFact1;
            tmp.Latitude = 2.^(26:-1:0)*flippedBits(193:219)/scaleFact1;
        case 27
            tmp.Longitude = 2.^(27:-1:0)*flippedBits(48:75)/scaleFact2;
            tmp.Latitude = 2.^(26:-1:0)*flippedBits(66:92)/scaleFact2;
        otherwise
            tmp.MMSI = 0;
            tmp.Longitude = 0;
            tmp.Latitude = 0;
    end
    crcCnt = crcCnt + 1;
else
    tmp.MessageBytes = char(zeros(1,90));
    tmp.MMSI = 0;
    tmp.Longitude = 0;
    tmp.Latitude = 0; 
end
if(validCRC)
    lenMsg = length(tmp.MessageBytes);
    MessageChar = tmp.MessageBytes.';
    info.MessageBytes(crcCnt,1:lenMsg) = MessageChar(1,1:lenMsg);
    info.MMSI(crcCnt) = tmp.MMSI;
    info.Longitude(crcCnt) = tmp.Longitude;
    info.Latitude(crcCnt) = tmp.Latitude;
end
% Increment the Packet counter
pktCnt = pktCnt + 1;

end

% Bit unstuffing by discarding the stuffed bits
function bitsOut = unStuff(bitsIn)
onesCount = 0;
bitsIn = double(bitsIn);
bitsOut = zeros(length(bitsIn),1);
bitsOutIdx = 1;
for ii = 1:length(bitsIn)
    if onesCount < 5
        bitsOut(bitsOutIdx) = bitsIn(ii);
        bitsOutIdx = bitsOutIdx+1;
    end
    if bitsIn(ii) == 1
        onesCount = onesCount+1;
    else
        onesCount = 0;
    end
end
bitsOutIdx = min(length(bitsIn),bitsOutIdx);
bitsOut = bitsOut(1:bitsOutIdx);
end

% Flip bits of each byte from left to right
function flippedBits = flipBytes(bitsIn)
nBytes = length(bitsIn)/8;
r1 = reshape(bitsIn,8,nBytes);
r2 = flipud(r1);
flippedBits = r2(:);
end

% Converts bits to hexadecimal characters
function hexChars = bitsToHex(msgBits)
nChars = length(msgBits)/4;
hexChars = char(zeros(nChars,1));
for ii=1:nChars
    bits=msgBits((ii-1)*4+1:ii*4);
    ch=dec2hex(2.^(3:-1:0)*bits);
    hexChars(ii)=ch;
end
end
