function rcvFreqComp = helperAISRxPhyFreqComp(rcv,samplerate)
% helperAISRxPhyFreqComp AIS Carrier frequency compensation
%   RCVFREQCOMP = helperAISRxPhyFreqComp(RCV,SAMPLERATE) estimate and
%   compensates for the carrier frequency offset in the received AIS signal,
%   RCV and outputs the compensated signal, RCVFREQCOMP.
%
%
%   See also AISExample, AISExampleApp.

%   Copyright 2018 The MathWorks, Inc.

% This prevents implicit expansion from being used in:
% rcv.*exp(1j*2*pi*(frShift/samplerate)*(0:length(rcv)-1)).';
coder.noImplicitExpansionInFunction;
rcvFFT = abs(fftshift(fft(rcv)));
idx = find(rcvFFT == max(rcvFFT));
frShift = (floor(length(rcv)/2)-idx)*(samplerate)/length(rcvFFT);
rcvFreqComp = rcv.*exp(1j*2*pi*(frShift/samplerate)*(0:length(rcv)-1)).'; 
end
