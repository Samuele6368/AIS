function [demodBits,prbdetFlag] = helperAISRxPhySyncDemod(rcv,aisParam)
% helperAISRxPhySyncDemod AIS synchronization and demodulation

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

% FIX: comm.PreambleDetector richiede tassativamente un vettore colonna.
% Se demodBits e' un vettore riga (cosa che puo' accadere dopo syncPhase
% su certi buffer), la chiamata genera "Expected input to be empty,
% scalar or a column vector". Il (:) risolve il problema in tutti i casi.
inputVec = (2*demodBits - 1);
inputVec = inputVec(:);

[indx,~] = prbdet(inputVec);

if(isempty(indx))
  prbdetFlag = 0;
else
  prbdetFlag = 1;
end

end

% Synchronization based on angles
function rxDownsample = syncPhase(rcv,aisParam)

rcvAngles = unwrap(angle(rcv));
lenCorrWin = 2*length(aisParam.syncAngles);

if (length(rcvAngles) > lenCorrWin)
  [acor,lag] = xcorr(aisParam.syncAngles, rcvAngles(1:lenCorrWin));
  [~,I] = max(abs(acor));
  lagDiff = lag(I);
  Index = lagDiff;
  idx = -Index+1;
else
  idx = 1;
end

samplePhase = mod(idx, aisParam.SamplesPerSymbol) + floor(aisParam.SamplesPerSymbol/2);
rxDownsample = rcvAngles(samplePhase:aisParam.SamplesPerSymbol:end);

end