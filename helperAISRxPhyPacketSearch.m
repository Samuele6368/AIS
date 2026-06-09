function [rcvTrim,rcvBoundary] = helperAISRxPhyPacketSearch(rcv,aisParam)
% helperAISRxPhyPacketSearch AIS packet search
%
%   [RCVTRIM, RCVBOUNDARY] = helperAISRxPhyPacketSearch(RCV,AISPARAM)
%   searches for the strongest burst in the received signal, RCV, by
%   dividing into multiple windows. RCVTRIM, is the strongest burst with
%   RCVBOUNDARY, as boundaries w.r.t RCV.
%   
%   AISPARAM is a structure containing AIS system parameters.
%
%   RCVTRIM is the strongest burst.
%
%   RCVBOUNDARY boundaries corresponding to the strongest burst with
%   respect to received signal, RCV.
%
%   See also AISExample, AISExampleApp.

%   Copyright 2018 The MathWorks, Inc.

% Divide the received signal into multiple windows
nofWindows = floor(length(rcv)/aisParam.windowLen);

% Search for strong window
winMag = sum(reshape(abs(rcv(1:nofWindows*aisParam.windowLen)),aisParam.windowLen,nofWindows));
diffMag = diff(winMag);
[maxVal,maxIndex] = max(diffMag);
meanVal = mean(abs(diffMag));
maxIndex = max(2,maxIndex);
maxIndex = min(maxIndex,nofWindows-2);

if maxVal > meanVal
    tmp1 = diffMag(maxIndex)-diffMag(maxIndex-1);
    tmp2 = diffMag(maxIndex)-diffMag(maxIndex+1);
    if tmp1 > tmp2
        startIndex = maxIndex*aisParam.windowLen;
    else
        startIndex = max(1,(maxIndex-1)*aisParam.windowLen);
    end
else
    startIndex = 1;
end

% Trim the received signal based on startIndex
endIndex = min(length(rcv),startIndex+aisParam.MaxPacketLength);
rcvBoundary  = [startIndex endIndex];
rcvTrim = rcv(startIndex:endIndex);
end