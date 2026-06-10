function [aisParam, sigSrc] = helperAISConfig(varargin)
%helperAISConfig AIS system parameters
%   [AISPARAM,SIGSRC] = helperAISConfig() returns AIS system parameters,
%   AISPARAM and signal source parameters, SIGSRC.
%
%   See also AISExample, AISExampleApp.
%   Copyright 2018-2022 The MathWorks, Inc.

narginchk(0, 1);

% AIS system parameters
symbolRate       = 9600;
samplesPerSymbol = 24;
sampleRate       = symbolRate * samplesPerSymbol;

if nargin == 0
    userInput.Duration          = 10;
    userInput.FrontEndSampleRate = sampleRate;
    userInput.RadioAddress      = '0';
    userInput.SignalSourceType  = ExampleSourceType.Captured;
    userInput.SignalFilename    = 'ais_capture.bb';
    userInput.CenterFrequency   = 162.025e6;
    userInput.launchMap         = 0;
    userInput.logData           = 0;
else
    tmp = varargin{1};
    if isstruct(tmp) || isa(tmp, 'ExampleController')
        userInput = varargin{1};
    else
        userInput.Duration          = 10;
        userInput.FrontEndSampleRate = tmp;
        userInput.RadioAddress      = '0';
        userInput.SignalSourceType  = ExampleSourceType.Captured;
        userInput.SignalFilename    = 'ais_capture.bb';
        userInput.CenterFrequency   = 162.025e6;
        userInput.launchMap         = 0;
        userInput.logData           = 0;
    end
end

% Create signal source
switch userInput.SignalSourceType
    % ------------------------------------------------------------------
    case ExampleSourceType.Captured
        bbFileName = userInput.SignalFilename;
        sigSrc = comm.BasebandFileReader(bbFileName);
        frontEndSampleRate = sigSrc.SampleRate;
        
        aisParam.isSourceRadio         = false;
        aisParam.isSourceRTLSDRRadio   = false;
        aisParam.isSourceUSRPRadio     = false;
        aisParam.isSourcePlutoSDRRadio = false;
        
        sigSrc.CyclicRepetition = true;
        sigSrc.SamplesPerFrame  = 262144;
        aisParam.FrameDuration  = 0.23;

    % ------------------------------------------------------------------
    case ExampleSourceType.RTLSDRRadio
        frontEndSampleRate = sampleRate;
        sigSrc = comm.SDRRTLReceiver( ...
            'CenterFrequency', userInput.CenterFrequency, ...
            'EnableTunerAGC',  false, ...
            'TunerGain',       60, ...
            'SampleRate',      sampleRate, ...
            'OutputDataType',  'single', ...
            'SamplesPerFrame', 262144);
            
        aisParam.isSourceRadio         = true;
        aisParam.isSourceRTLSDRRadio   = true;
        aisParam.isSourceUSRPRadio     = false;
        aisParam.isSourcePlutoSDRRadio = false;
        aisParam.FrameDuration = sigSrc.SamplesPerFrame / frontEndSampleRate;

    % ------------------------------------------------------------------
    case ExampleSourceType.USRPRadio
        frontEndSampleRate = sampleRate;
        
        % --- FORZA CONNESSIONE USB DIRETTA ---
        aisParam.Platform = 'B200'; 
        sigSrc = comm.SDRuReceiver( ...
            'Platform',        'B200', ...
            "SerialNum",       "34A9057", ...
            'MasterClockRate', 18.432e6, ...
            'OutputDataType',  'single');
        % -------------------------------------

        sigSrc.DecimationFactor  = sigSrc.MasterClockRate / frontEndSampleRate;
        sigSrc.Gain              = 30;
        sigSrc.CenterFrequency   = userInput.CenterFrequency;
        sigSrc.SamplesPerFrame   = 262144;
        
        aisParam.MasterClockRate       = sigSrc.MasterClockRate;
        aisParam.DecimationFactor      = sigSrc.DecimationFactor;
        aisParam.Gain                  = sigSrc.Gain;
        aisParam.isSourceRadio         = true;
        aisParam.isSourceRTLSDRRadio   = false;
        aisParam.isSourceUSRPRadio     = true;
        aisParam.isSourcePlutoSDRRadio = false;
        aisParam.FrameDuration         = sigSrc.SamplesPerFrame / frontEndSampleRate;

    % ------------------------------------------------------------------
    case ExampleSourceType.PlutoSDRRadio
        frontEndSampleRate = sampleRate;
        sigSrc = sdrrx('Pluto', ...
            'CenterFrequency',   userInput.CenterFrequency, ...
            'GainSource',        'Manual', ...
            'Gain',              30, ...
            'BasebandSampleRate', frontEndSampleRate, ...
            'OutputDataType',    'single', ...
            'SamplesPerFrame',   262144);
            
        aisParam.isSourceRadio         = true;
        aisParam.isSourceRTLSDRRadio   = false;
        aisParam.isSourceUSRPRadio     = false;
        aisParam.isSourcePlutoSDRRadio = true;
        aisParam.FrameDuration = sigSrc.SamplesPerFrame / frontEndSampleRate;

    % ------------------------------------------------------------------
    otherwise
        error('comm:examples:Exit', 'Aborted.');
end

% Parametri comuni AIS
aisParam.FrontEndSampleRate = frontEndSampleRate;
aisParam.SampleRate         = frontEndSampleRate;
aisParam.SamplesPerSymbol   = samplesPerSymbol;
aisParam.MinPacketLength    = 184 * samplesPerSymbol;
aisParam.MaxPacketLength    = 480 * samplesPerSymbol;
aisParam.windowLen          = 1024;
aisParam.BT                 = 0.3;
aisParam.span               = 3;
aisParam.Prehistory         = [1 -1];

h = gaussdesign(aisParam.BT, aisParam.span, aisParam.SamplesPerSymbol);
aisParam.h = h / std(h);

aisParam.SamplesPerFrame = sigSrc.SamplesPerFrame;
aisParam.TrainingSeq     = logical([1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0]);
aisParam.TrainingSeqNRZI = logical([1 0 0 1 1 0 0 1 1 0 0 1 1 0 0 1 1 0 0 1 1 0 0 1]);

[aisParam.syncSyms, aisParam.syncAngles] = helperAISSyncGen(aisParam);
end