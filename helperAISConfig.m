function [aisParam, sigSrc] = helperAISConfig(varargin)
%helperAISConfig AIS system parameters
% [AISPARAM,SIGSRC] = helperAISConfig() returns AIS system parameters,
% AISPARAM and signal source parameters, SIGSRC.
%
% Sorgenti supportate:
%   ExampleSourceType.Captured       - file .bb registrato
%   ExampleSourceType.RTLSDRRadio    - RTL-SDR (es. RTL2832U)
%   ExampleSourceType.PlutoSDRRadio  - ADALM-PLUTO
%   ExampleSourceType.USRPRadio      - USRP (es. B200/B205mini)
%
% See also AISExample, AISExampleApp.

% Copyright 2018-2022 The MathWorks, Inc.

narginchk(0, 1);

% Parametri AIS fissi
symbolRate      = 9600;
samplesPerSymbol = 24;
sampleRate      = symbolRate * samplesPerSymbol;   % 230400 Hz

% --- Input utente ---
if nargin == 0
  userInput.Duration          = 10;
  userInput.FrontEndSampleRate = sampleRate;
  userInput.RadioAddress      = '0';
  userInput.SignalSourceType  = ExampleSourceType.Captured;
  userInput.SignalFilename    = 'ais_capture.bb';
  userInput.CenterFrequency  = 162.025e6;
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
    userInput.CenterFrequency  = 162.025e6;
    userInput.launchMap         = 0;
    userInput.logData           = 0;
  end
end

% ======================================================================
%  SELEZIONE SORGENTE SEGNALE
% ======================================================================
switch userInput.SignalSourceType

  % --------------------------------------------------------------------
  case ExampleSourceType.Captured
    bbFileName = userInput.SignalFilename;
    sigSrc = comm.BasebandFileReader(bbFileName);
    frontEndSampleRate = sigSrc.SampleRate;

    aisParam.isSourceRadio        = false;
    aisParam.isSourceRTLSDRRadio  = false;
    aisParam.isSourceUSRPRadio    = false;
    aisParam.isSourcePlutoSDRRadio = false;

    sigSrc.CyclicRepetition = true;
    sigSrc.SamplesPerFrame  = 262144;
    aisParam.FrameDuration  = 0.23;

  % --------------------------------------------------------------------
  case ExampleSourceType.RTLSDRRadio
    % RTL-SDR: max sample rate affidabile ~2.56 MS/s.
    % AIS richiede 230400 Hz -> il driver effettua decimazione interna.
    frontEndSampleRate = sampleRate;   % 230400 Hz

    radioAddr = userInput.RadioAddress;
    if isempty(radioAddr)
      radioAddr = '0';
    end

    sigSrc = comm.SDRRTLReceiver( ...
      'RadioAddress',    radioAddr, ...
      'CenterFrequency', userInput.CenterFrequency, ...
      'EnableTunerAGC',  false, ...
      'TunerGain',       60, ...
      'SampleRate',      frontEndSampleRate, ...
      'OutputDataType',  'single', ...
      'SamplesPerFrame', 262144);

    aisParam.isSourceRadio        = true;
    aisParam.isSourceRTLSDRRadio  = true;
    aisParam.isSourceUSRPRadio    = false;
    aisParam.isSourcePlutoSDRRadio = false;
    aisParam.FrameDuration        = sigSrc.SamplesPerFrame / frontEndSampleRate;

  % --------------------------------------------------------------------
  case ExampleSourceType.PlutoSDRRadio
    % ADALM-PLUTO: sample rate minimo ~521 kHz, usiamo 522240 Hz
    % (= sampleRate * 2.266...) e poi decimiamo via resample.
    % Per semplicità usiamo direttamente 230400 Hz che Pluto accetta
    % a partire dalle versioni firmware recenti; in caso di errore
    % alzare a 521280 Hz e aggiungere un decimatore.
    frontEndSampleRate = sampleRate;   % 230400 Hz (verificare con il firmware)

    radioAddr = userInput.RadioAddress;
    if isempty(radioAddr)
      radioAddr = '192.168.2.1';
    end

    sigSrc = sdrrx('Pluto', ...
      'RadioID',          radioAddr, ...
      'CenterFrequency',  userInput.CenterFrequency, ...
      'GainSource',       'Manual', ...
      'Gain',             50, ...
      'BasebandSampleRate', frontEndSampleRate, ...
      'OutputDataType',   'single', ...
      'SamplesPerFrame',  262144);

    aisParam.isSourceRadio        = true;
    aisParam.isSourceRTLSDRRadio  = false;
    aisParam.isSourceUSRPRadio    = false;
    aisParam.isSourcePlutoSDRRadio = true;
    aisParam.FrameDuration        = sigSrc.SamplesPerFrame / frontEndSampleRate;

  % --------------------------------------------------------------------
  case ExampleSourceType.USRPRadio
    frontEndSampleRate = sampleRate;   % 230400 Hz

    sigSrc = comm.SDRuReceiver( ...
      'Platform',         'B200', ...
      'SerialNum',        userInput.RadioAddress, ...
      'MasterClockRate',  18.432e6, ...
      'OutputDataType',   'single');

    sigSrc.DecimationFactor = round(sigSrc.MasterClockRate / frontEndSampleRate);
    sigSrc.Gain             = 70;
    sigSrc.CenterFrequency  = userInput.CenterFrequency;
    sigSrc.SamplesPerFrame  = 262144;

    aisParam.MasterClockRate    = sigSrc.MasterClockRate;
    aisParam.DecimationFactor   = sigSrc.DecimationFactor;
    aisParam.Gain               = sigSrc.Gain;
    aisParam.isSourceRadio      = true;
    aisParam.isSourceRTLSDRRadio  = false;
    aisParam.isSourceUSRPRadio  = true;
    aisParam.isSourcePlutoSDRRadio = false;
    aisParam.FrameDuration      = sigSrc.SamplesPerFrame / frontEndSampleRate;

  % --------------------------------------------------------------------
  otherwise
    error('comm:examples:Exit', 'Sorgente segnale non riconosciuta.');
end

% ======================================================================
%  PARAMETRI AIS COMUNI
% ======================================================================
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

aisParam.SamplesPerFrame     = sigSrc.SamplesPerFrame;
aisParam.TrainingSeq         = logical([1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0]);
aisParam.TrainingSeqNRZI     = logical([1 0 0 1 1 0 0 1 1 0 0 1 1 0 0 1 1 0 0 1 1 0 0 1]);

[aisParam.syncSyms, aisParam.syncAngles] = helperAISSyncGen(aisParam);

end