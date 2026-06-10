function [demodBits,prbdetFlag] = helperAISRxPhySyncDemod(rcv,aisParam)
%helperAISRxPhySyncDemod AIS synchronization and demodulation
%
%   [DEMODBITS,PRBDETFLAG] = helperAISRxPhySyncDemod(RCV,AISPARAM) performs
%   synchronization and GMSK demodulation of the AIS signal, RCV and
%   outputs the demodulated bits, DEMODBITS along with training sequence
%   detection flag, PRBDETFLAG.
%  
%   DEMODBITS bits obtained after performing GMSK demodulation on received
%   AIS signal, RCV.
%
%   PRBDETFLAG determines whether preamble is detected or not.
%
%   See also AISExample, AISExampleApp.

%   Copyright 2018 The MathWorks, Inc.


% Perform synchronization based on angles
rxDownsample = syncPhase(rcv,aisParam);

% Make bit decisions
demodBits = zeros(size(rxDownsample));
idx = find(abs(diff(rxDownsample)) > pi/4);
demodBits(idx) = 1;

% Check for the training sequence in the decoded bits
prbdet = comm.PreambleDetector('Input','Symbol','Detections','First');
prbdet.Preamble = (2*[1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0]-1).';
prbdet.Threshold = 20;
% detect preamble (con fix per colonna)
    demodBits = demodBits(:);
    [indx,~] = prbdet(2*demodBits-1);
if(isempty(indx))
    prbdetFlag = 0;
else
    prbdetFlag = 1;
end
end

% Synchronization based on angles
function rxDownsample = syncPhase(rcv,aisParam)
% Compute the angles corresponding to the received signal
rcvAngles = unwrap(angle(rcv));

% Perform correlation to find the starting index
lenCorrWin = 2*length(aisParam.syncAngles);
if (length(rcvAngles) > lenCorrWin)
    % Correlate with known preamble sample phases
    [acor,lag] = xcorr(aisParam.syncAngles,rcvAngles(1:lenCorrWin));
    [~,I] = max(abs(acor));
    lagDiff = lag(I);
    Index = lagDiff;
    idx = -Index+1;
else
    idx = 1;
end

% Compute the best sample phase for making bit decisions
samplePhase = mod(idx,aisParam.SamplesPerSymbol)+floor(aisParam.SamplesPerSymbol/2);

% Downsample the signal to 1 sample per symbol
rxDownsample = rcvAngles(samplePhase:aisParam.SamplesPerSymbol:end);

end
