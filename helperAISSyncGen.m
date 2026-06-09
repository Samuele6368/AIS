function [syncSyms, syncAngles] = helperAISSyncGen(aisParam)
% helperAISSyncGen AIS training sequence generation
%   [SYNCSYMS,SYNCANGLES] = helperAISSyncGen(AISPARAM) generates GMSK
%   samples, SYNCSYMS and its corresponding angles, SYNCANGLES for given
%   AIS training sequence.
%
%   AISPARAM is a structure containing AIS system parameters.
%
%   SYNCSYMS GMSK samples.
%
%   SYNCANGLES angles corresponding to the GMSK samples, SYNCSYMS.

% Copyright 2018, The MathWorks, Inc.

% Set up GMSK Modulator
persistent mod
if isempty(mod)
    mod = comm.GMSKModulator('BandwidthTimeProduct',aisParam.BT,'SamplesPerSymbol',...
        aisParam.SamplesPerSymbol,'BitInput',true,'PulseLength',...
        aisParam.span,'SymbolPrehistory',aisParam.Prehistory);
end

% Generate GMSK waveform for training sequence
syncSyms = mod(aisParam.TrainingSeqNRZI');
syncAngles = unwrap(angle(syncSyms));
end
